#!/bin/bash

echo "=== Проверка статуса MongoDB кластера ==="

echo "1. Статус шардирования:"
docker compose exec -T mongos_router mongosh --port 27020 --quiet --eval "sh.status()"

echo -e "\n2. Распределение данных по шардам:"
docker compose exec -T mongos_router mongosh --port 27020 --quiet --eval <<EOF
use somedb; 
db.helloDoc.getShardDistribution()
EOF

echo -e "\n4. Проверка количества документов на шарде 1"

docker compose exec -T shard1 mongosh --port 27018 --quiet --eval <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo -e "Проверка количества документов на шарде 2"

docker compose exec -T shard2 mongosh --port 27019 --quiet --eval <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo -e "\n=== Проверка завершена ==="
