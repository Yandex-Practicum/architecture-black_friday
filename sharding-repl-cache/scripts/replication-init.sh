#!/bin/bash
set -euo pipefail

# Инициализация шардированного кластера MongoDB с репликацией:
# - configsvr: RS configReplSet (3 члена)
# - shard1: RS shard1rs (3 члена)
# - shard2: RS shard2rs (3 члена)
# - mongos: добавление шардов, включение шардирования и шардинг коллекции

echo "=========================================="
echo "Инициализация MongoDB с репликацией"
echo "=========================================="

echo ""
echo "[1/4] Инициализация replica set для configsvr (configReplSet) с 3 членами..."
docker compose exec -T configsvr-1 mongosh --port 27019 --quiet <<'EOF'
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [
    { _id: 0, host: "configsvr-1:27019" },
    { _id: 1, host: "configsvr-2:27019" },
    { _id: 2, host: "configsvr-3:27019" }
  ]
})
EOF

echo "Ожидание готовности configsvr replica set..."
sleep 5

echo ""
echo "[2/4] Инициализация replica set для shard1 (shard1rs) с 3 членами..."
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<'EOF'
rs.initiate({
  _id: "shard1rs",
  members: [
    { _id: 0, host: "shard1-1:27018" },
    { _id: 1, host: "shard1-2:27018" },
    { _id: 2, host: "shard1-3:27018" }
  ]
})
EOF

echo "Ожидание готовности shard1 replica set..."
sleep 5

echo ""
echo "[3/4] Инициализация replica set для shard2 (shard2rs) с 3 членами..."
docker compose exec -T shard2-1 mongosh --port 27020 --quiet <<'EOF'
rs.initiate({
  _id: "shard2rs",
  members: [
    { _id: 0, host: "shard2-1:27020" },
    { _id: 1, host: "shard2-2:27020" },
    { _id: 2, host: "shard2-3:27020" }
  ]
})
EOF

echo "Ожидание готовности shard2 replica set..."
sleep 5

echo ""
echo "[4/4] Конфигурация mongos: добавление шардов, включение шардирования БД и коллекции..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
// Добавляем шарды в кластер
sh.addShard("shard1rs/shard1-1:27018,shard1-2:27018,shard1-3:27018")
sh.addShard("shard2rs/shard2-1:27020,shard2-2:27020,shard2-3:27020")

// Включаем шардирование БД somedb
sh.enableSharding("somedb")

// Переключаемся на БД somedb
use somedb

// Создаем хэш-индекс на _id перед шардированием (требуется в новых версиях MongoDB)
db.helloDoc.createIndex({ _id: "hashed" })

// Шардируем коллекцию somedb.helloDoc по хэшу _id
sh.shardCollection("somedb.helloDoc", { _id: "hashed" })

// Выводим статус кластера
sh.status()
EOF

echo ""
echo "=========================================="
echo "Инициализация завершена успешно!"
echo "=========================================="
echo ""
echo "Проверка статуса replica sets:"
echo ""

echo "Config Server Replica Set:"
docker compose exec -T configsvr-1 mongosh --port 27019 --quiet --eval "rs.status().members.map(m => ({name: m.name, state: m.stateStr}))" 2>/dev/null || echo "Ошибка получения статуса configsvr"

echo ""
echo "Shard1 Replica Set:"
docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval "rs.status().members.map(m => ({name: m.name, state: m.stateStr}))" 2>/dev/null || echo "Ошибка получения статуса shard1"

echo ""
echo "Shard2 Replica Set:"
docker compose exec -T shard2-1 mongosh --port 27020 --quiet --eval "rs.status().members.map(m => ({name: m.name, state: m.stateStr}))" 2>/dev/null || echo "Ошибка получения статуса shard2"

echo ""
echo "=========================================="
