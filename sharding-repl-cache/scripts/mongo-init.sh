#!/bin/bash
set -e

echo "Подключение к mongos и инициализация шардирования..."

docker compose exec -T mongos mongosh --port 27020 --quiet <<EOF
use somedb

// включаем шардирование БД
sh.enableSharding("somedb")

// шардируем коллекцию по hashed _id
sh.shardCollection("somedb.helloDoc", { _id: "hashed" })

// наполняем данными
for (let i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({ age: i, name: "ly" + i })
}

// проверка общего количества
print("TOTAL DOCUMENTS:")
db.helloDoc.countDocuments()
EOF

echo "Проверка документов на shard1..."

docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo "Проверка документов на shard2..."

docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo "Инициализация завершена"