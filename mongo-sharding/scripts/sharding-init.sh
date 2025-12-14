#!/bin/bash
set -euo pipefail

# Инициализация шардированного кластера MongoDB:
# - configsvr: RS configReplSet
# - shard1: RS shard1rs
# - shard2: RS shard2rs
# - mongos: добавление шардов, включение шардирования и шардинг коллекции

echo "[1/4] Инициализация replica set для configsvr (configReplSet)..."
docker compose exec -T configsvr mongosh --port 27019 --quiet <<'EOF'
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [
    { _id: 0, host: "configsvr:27019" }
  ]
})
EOF

# Небольшая пауза для старта RS
sleep 2

echo "[2/4] Инициализация replica set для shard1 (shard1rs)..."
docker compose exec -T shard1 mongosh --port 27018 --quiet <<'EOF'
rs.initiate({
  _id: "shard1rs",
  members: [
    { _id: 0, host: "shard1:27018" }
  ]
})
EOF

echo "[3/4] Инициализация replica set для shard2 (shard2rs)..."
docker compose exec -T shard2 mongosh --port 27020 --quiet <<'EOF'
rs.initiate({
  _id: "shard2rs",
  members: [
    { _id: 0, host: "shard2:27020" }
  ]
})
EOF

# Небольшая пауза для избежания гонок
sleep 2

echo "[4/4] Конфигурация mongos: добавление шардов, включение шардирования БД и коллекции..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
sh.addShard("shard1rs/shard1:27018")
sh.addShard("shard2rs/shard2:27020")

// Включаем шардирование БД somedb
sh.enableSharding("somedb")

// Шардируем коллекцию somedb.helloDoc по хэшу _id
sh.shardCollection("somedb.helloDoc", { _id: "hashed" })

// Выводим статус кластера
sh.status()
EOF

echo "Инициализация шардирования завершена."
