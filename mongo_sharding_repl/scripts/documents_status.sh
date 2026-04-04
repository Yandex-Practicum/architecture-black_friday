#!/bin/bash
echo "========================================="
echo "Система 2: Статус кластера"
echo "========================================="

echo ""
echo "=== 1. Общее количество документов ==="
TOTAL=$(docker exec mongos_router mongosh --host mongos_router --port 27020 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()")
echo "Всего документов: $TOTAL"

echo ""
echo "=== 2. Распределение по шардам ==="
docker exec mongos_router mongosh --host mongos_router --port 27020 --eval "db.getSiblingDB('somedb').helloDoc.getShardDistribution()"

echo ""
echo "=== 3. Проверка репликации (данные на всех узлах) ==="
echo "Shard 1 - Primary:"
docker exec shard1_primary mongosh --host shard1_primary --port 27018 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"
echo "Shard 1 - Secondary 1:"
docker exec shard1_secondary_1 mongosh --host shard1_secondary_1 --port 27018 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"
echo "Shard 1 - Secondary 2:"
docker exec shard1_secondary_2 mongosh --host shard1_secondary_2 --port 27018 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"

echo ""
echo "Shard 2 - Primary:"
docker exec shard2_primary mongosh --host shard2_primary --port 27019 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"
echo "Shard 2 - Secondary 1:"
docker exec shard2_secondary_1 mongosh --host shard2_secondary_1 --port 27019 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"
echo "Shard 2 - Secondary 2:"
docker exec shard2_secondary_2 mongosh --host shard2_secondary_2 --port 27019 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"

echo ""
echo "=== 4. Статус ReplicaSet'ов ==="
echo "Config Server:"
docker exec config_service_1 mongosh --host config_service_1 --port 27017 --quiet --eval "rs.status().members.map(m => ({name: m.name, stateStr: m.stateStr}))"
echo ""
echo "Shard 1:"
docker exec shard1_primary mongosh --host shard1_primary --port 27018 --quiet --eval "rs.status().members.map(m => ({name: m.name, stateStr: m.stateStr}))"
echo ""
echo "Shard 2:"
docker exec shard2_primary mongosh --host shard2_primary --port 27019 --quiet --eval "rs.status().members.map(m => ({name: m.name, stateStr: m.stateStr}))"

echo "✅ Готово"