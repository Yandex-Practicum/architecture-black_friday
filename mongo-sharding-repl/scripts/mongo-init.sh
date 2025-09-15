#!/bin/bash
set -e

echo "Инициализация шардированного кластера MongoDB с репликацией..."
echo "==============================================================="

# 1. Config Server
echo "1. Инициализация Config Server Replica Set..."
docker compose exec -T configSvr mongosh --port 27018 --quiet <<EOF
try {
    rs.initiate({
        _id: "configrs",
        configsvr: true,
        members: [
            { _id: 0, host: "configSvr:27018" }
        ]
    })
    print("Config Server Replica Set инициализирован")
} catch(e) {
    print("Config Server уже инициализирован или ошибка:", e.message)
}
EOF

echo "Ожидание готовности Config Server..."
sleep 10

# 2. Shard 1 Replica Set
echo "2. Инициализация Shard 1 Replica Set..."
docker compose exec -T shard1_primary mongosh --port 27011 --quiet <<EOF
try {
    rs.initiate({
        _id: "shard1rs",
        members: [
            { _id: 0, host: "shard1_primary:27011", priority: 3 },
            { _id: 1, host: "shard1_secondary1:27011", priority: 2 },
            { _id: 2, host: "shard1_secondary2:27011", priority: 1 }
        ]
    })
    print("Shard 1 Replica Set инициализирован")
} catch(e) {
    print("Shard 1 уже инициализирован или ошибка:", e.message)
}
EOF

# 3. Shard 2 Replica Set
echo "3. Инициализация Shard 2 Replica Set..."
docker compose exec -T shard2_primary mongosh --port 27021 --quiet <<EOF
try {
    rs.initiate({
        _id: "shard2rs",
        members: [
            { _id: 0, host: "shard2_primary:27021", priority: 3 },
            { _id: 1, host: "shard2_secondary1:27021", priority: 2 },
            { _id: 2, host: "shard2_secondary2:27021", priority: 1 }
        ]
    })
    print("Shard 2 Replica Set инициализирован")
} catch(e) {
    print("Shard 2 уже инициализирован или ошибка:", e.message)
}
EOF

echo "Ожидание готовности всех Replica Sets..."
sleep 25

# 4. Добавление шардов в кластер
echo "4. Добавление шардов в кластер..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
try {
    sh.addShard("shard1rs/shard1_primary:27011,shard1_secondary1:27011,shard1_secondary2:27011")
    print("Shard 1 Replica Set добавлен в кластер")
} catch(e) {
    print("Ошибка добавления Shard 1:", e.message)
}

try {
    sh.addShard("shard2rs/shard2_primary:27021,shard2_secondary1:27021,shard2_secondary2:27021")
    print("Shard 2 Replica Set добавлен в кластер")
} catch(e) {
    print("Ошибка добавления Shard 2:", e.message)
}
EOF

# 5. Включение шардирования базы
echo "5. Настройка шардирования базы данных..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
try {
    sh.enableSharding("somedb")
    print("Шардирование включено для базы somedb")
} catch(e) {
    print("Ошибка включения шардирования:", e.message)
}
EOF

# 6. Создание шардированной коллекции
echo "6. Создание шардированной коллекции..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
use somedb
try {
    db.helloDoc.createIndex({"name": 1})
    print("Индекс создан")

    sh.shardCollection("somedb.helloDoc", { "name": "hashed" })
    print("Коллекция helloDoc шардирована с hashed sharding")
} catch(e) {
    print("Ошибка создания коллекции:", e.message)
}
EOF

# 7. Заполнение данными
echo "7. Заполнение базы данными..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
use somedb
try {
    for(var i = 0; i < 4000; i++) {
        db.helloDoc.insertOne({
            age: i % 100,
            name: "user" + String(i).padStart(5, '0'),
            timestamp: new Date(),
            data: "sample_data_" + i
        })
    }
    print("Добавлено 4000 документов")
} catch(e) {
    print("Ошибка добавления данных:", e.message)
}
EOF

# 8. Проверка состояния
echo "8. Проверка состояния кластера..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
use somedb
var totalCount = db.helloDoc.countDocuments()
print("Всего документов:", totalCount)
db.helloDoc.getShardDistribution()
EOF

echo "Статус Shard 1 Replica Set:"
docker compose exec -T shard1_primary mongosh --port 27011 --quiet <<EOF
rs.status().members.forEach(function(m){ print(m.name,"-",m.stateStr) })
EOF

echo "Статус Shard 2 Replica Set:"
docker compose exec -T shard2_primary mongosh --port 27021 --quiet <<EOF
rs.status().members.forEach(function(m){ print(m.name,"-",m.stateStr) })
EOF

echo "Инициализация кластера завершена!"
