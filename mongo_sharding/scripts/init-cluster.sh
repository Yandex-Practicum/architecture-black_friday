#!/bin/bash

echo "=== 1. Инициализация Config Server ==="
docker exec config_service mongosh --host config_service --port 27017 --eval "rs.initiate({_id: 'config_repl', configsvr: true, members: [{_id: 0, host: 'config_service:27017'}]})"

echo "=== 2. Инициализация Shard 1 ==="
docker exec shard1 mongosh --host shard1 --port 27018 --eval "rs.initiate({_id: 'shard1_repl', members: [{_id: 0, host: 'shard1:27018'}]})"

echo "=== 3. Инициализация Shard 2 ==="
docker exec shard2 mongosh --host shard2 --port 27019 --eval "rs.initiate({_id: 'shard2_repl', members: [{_id: 0, host: 'shard2:27019'}]})"

echo "=== 4. Ожидание 15 секунд ==="
sleep 15

echo "=== 5. Добавление шардов ==="
docker exec mongos_router mongosh --host mongos_router --port 27020 --eval "sh.addShard('shard1_repl/shard1:27018')"
docker exec mongos_router mongosh --host mongos_router --port 27020 --eval "sh.addShard('shard2_repl/shard2:27019')"
docker exec mongos_router mongosh --host mongos_router --port 27020 --eval "sh.enableSharding('somedb')"
docker exec mongos_router mongosh --host mongos_router --port 27020 --eval "sh.shardCollection('somedb.helloDoc', { 'user_id': 'hashed' })"

echo "=== 6. Проверка ==="
docker exec mongos_router mongosh --host mongos_router --port 27020 --eval "sh.status()"

echo "=== Готово! ==="