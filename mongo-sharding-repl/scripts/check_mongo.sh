#!/bin/bash

echo "=== Проверка статуса MongoDB ==="

echo "1. Статус шардирования:"
docker compose exec -T mongos_router mongosh --port 27020 --quiet --eval "sh.status()"

echo -e "\n2. Распределение данных по шардам:"
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
use somedb
db.helloDoc.getShardDistribution()
EOF

echo -e "\n3. Проверка количества документов на шарде 1 (через shard1-1):"
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo -e "\n4. Проверка количества документов на шарде 2 (через shard2-1):"
docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo -e "\n=== Проверка завершена ==="
