#!/bin/bash

echo "=== 1. Инициализация Config Server ReplicaSet ==="
docker exec config_service_1 mongosh --host config_service_1 --port 27017 --eval "
rs.initiate({
  _id: 'config_repl',
  configsvr: true,
  members: [
    { _id: 0, host: 'config_service_1:27017' },
    { _id: 1, host: 'config_service_2:27017' },
    { _id: 2, host: 'config_service_3:27017' }
  ]
})
"

# 2. Инициализация Shard 1 ReplicaSet
echo "=== 2. Инициализация Shard 1 ReplicaSet ==="
docker exec shard1_primary mongosh --host shard1_primary --port 27018 --eval "
rs.initiate({
  _id: 'shard1_repl',
  members: [
    { _id: 0, host: 'shard1_primary:27018' },
    { _id: 1, host: 'shard1_secondary_1:27018' },
    { _id: 2, host: 'shard1_secondary_2:27018' }
  ]
})
"

echo "=== 3. Инициализация Shard 2 ReplicaSet ==="
docker exec shard2_primary mongosh --host shard2_primary --port 27019 --eval "
rs.initiate({
  _id: 'shard2_repl',
  members: [
    { _id: 0, host: 'shard2_primary:27019' },
    { _id: 1, host: 'shard2_secondary_1:27019' },
    { _id: 2, host: 'shard2_secondary_2:27019' }
  ]
})
"

echo "=== 4. Ожидание 20 секунд для выбора PRIMARY ==="
sleep 20

echo "=== 5. Проверка статусов репликации ==="
echo "Config Server:"
docker exec config_service_1 mongosh --host config_service_1 --port 27017 --eval "rs.status().members.map(m => ({name: m.name, stateStr: m.stateStr}))"

echo "Shard 1:"
docker exec shard1_primary mongosh --host shard1_primary --port 27018 --eval "rs.status().members.map(m => ({name: m.name, stateStr: m.stateStr}))"

echo "Shard 2:"
docker exec shard2_primary mongosh --host shard2_primary --port 27019 --eval "rs.status().members.map(m => ({name: m.name, stateStr: m.stateStr}))"

echo "=== 6. Добавление шардов в кластер ==="
docker exec mongos_router mongosh --host mongos_router --port 27020 --eval "
sh.addShard('shard1_repl/shard1_primary:27018');
sh.addShard('shard2_repl/shard2_primary:27019');
sh.enableSharding('somedb');
sh.shardCollection('somedb.helloDoc', { 'user_id': 'hashed' });
"

echo "=== 7. Проверка Redis ==="
docker exec redis_1 redis-cli ping

echo "=== 8. Проверка статуса кластера ==="
docker exec mongos_router mongosh --host mongos_router --port 27020 --eval "sh.status()"

echo ""
echo "=== Готово! ==="
echo "Redis доступен"
echo "API подключен к Redis и MongoDB с чтением с реплик"