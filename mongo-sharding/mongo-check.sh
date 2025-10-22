#!/bin/bash

#Проверка количества записей на первой шарде
docker compose exec -T shard1 mongosh --port 27018 <<EOF
use somedb;
db.helloDoc.countDocuments();
exit;
EOF

#Проверка количества записей на второй шарде
docker compose exec -T shard2 mongosh --port 27019 <<EOF
use somedb;
db.helloDoc.countDocuments();
exit;
EOF