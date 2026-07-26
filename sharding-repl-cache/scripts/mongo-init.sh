#!/bin/bash

set -euo pipefail

wait_for_mongo() {
  local service=$1
  local port=$2

  until docker compose exec -T "$service" mongosh \
    --port "$port" \
    --quiet \
    --eval 'db.adminCommand({ping: 1}).ok' >/dev/null 2>&1
  do
    sleep 1
  done
}

wait_for_primary() {
  local service=$1
  local port=$2

  until docker compose exec -T "$service" mongosh \
    --port "$port" \
    --quiet \
    --eval 'if (!db.hello().isWritablePrimary) quit(1)' >/dev/null 2>&1
  do
    sleep 1
  done
}

wait_for_replica_set() {
  local service=$1
  local port=$2
  local expected_members=$3

  until docker compose exec -T "$service" mongosh \
    --port "$port" \
    --quiet \
    --eval "
      const status = rs.status();
      const healthy = status.members.filter(member => member.health === 1).length;
      const primary = status.members.some(member => member.stateStr === 'PRIMARY');
      if (healthy < $expected_members || !primary) quit(1);
    " >/dev/null 2>&1
  do
    sleep 1
  done
}

wait_for_mongo configSrv 27017
wait_for_mongo shard1-1 27018
wait_for_mongo shard1-2 27018
wait_for_mongo shard1-3 27018
wait_for_mongo shard2-1 27019
wait_for_mongo shard2-2 27019
wait_for_mongo shard2-3 27019

docker compose exec -T configSrv mongosh --port 27017 --quiet <<'EOF'
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [
    {_id: 0, host: "configSrv:27017"}
  ]
})
EOF

docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<'EOF'
rs.initiate({
  _id: "shard1",
  members: [
    {_id: 0, host: "shard1-1:27018"},
    {_id: 1, host: "shard1-2:27018"},
    {_id: 2, host: "shard1-3:27018"}
  ]
})
EOF

docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<'EOF'
rs.initiate({
  _id: "shard2",
  members: [
    {_id: 0, host: "shard2-1:27019"},
    {_id: 1, host: "shard2-2:27019"},
    {_id: 2, host: "shard2-3:27019"}
  ]
})
EOF

wait_for_primary configSrv 27017
wait_for_replica_set shard1-1 27018 3
wait_for_replica_set shard2-1 27019 3
wait_for_mongo mongos_router 27020

docker compose exec -T mongos_router mongosh --port 27020 --quiet <<'EOF'
sh.addShard("shard1/shard1-1:27018,shard1-2:27018,shard1-3:27018")
sh.addShard("shard2/shard2-1:27019,shard2-2:27019,shard2-3:27019")
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", {name: "hashed"})

use somedb
for (let i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({age: i, name: "ly" + i})
}
EOF

echo "Всего документов:"
docker compose exec -T mongos_router mongosh \
  --port 27020 \
  --quiet \
  --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments()'

echo "Документов на shard1:"
docker compose exec -T mongos_router mongosh \
  'mongodb://shard1-1:27018,shard1-2:27018,shard1-3:27018/somedb?replicaSet=shard1' \
  --quiet \
  --eval 'db.helloDoc.countDocuments()'

echo "Документов на shard2:"
docker compose exec -T mongos_router mongosh \
  'mongodb://shard2-1:27019,shard2-2:27019,shard2-3:27019/somedb?replicaSet=shard2' \
  --quiet \
  --eval 'db.helloDoc.countDocuments()'

echo "Узлов в replica set shard1:"
docker compose exec -T shard1-1 mongosh \
  --port 27018 \
  --quiet \
  --eval 'rs.status().members.length'

echo "Узлов в replica set shard2:"
docker compose exec -T shard2-1 mongosh \
  --port 27019 \
  --quiet \
  --eval 'rs.status().members.length'
