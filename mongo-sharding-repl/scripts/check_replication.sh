#!/bin/bash

echo "========================================="
echo "Checking Shard 1 Replica Set Status"
echo "========================================="
docker compose exec -T shard1_1 mongosh --port 27018 --quiet <<EOF
rs.status()
EOF

echo ""
echo "========================================="
echo "Checking Shard 2 Replica Set Status"
echo "========================================="
docker compose exec -T shard2_1 mongosh --port 27019 --quiet <<EOF
rs.status()
EOF

echo ""
echo "========================================="
echo "Total documents:"
echo "========================================="
docker compose exec -T mongos_router mongosh --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo ""
echo "========================================="
echo "Shard 1 documents:"
echo "========================================="
docker compose exec -T shard1_1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo ""
echo "========================================="
echo "Shard 2 documents:"
echo "========================================="
docker compose exec -T shard2_1 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo ""
echo "========================================="
echo "Shard distribution:"
echo "========================================="
docker compose exec -T mongos_router mongosh --quiet <<EOF
use somedb
db.helloDoc.getShardDistribution()
EOF
