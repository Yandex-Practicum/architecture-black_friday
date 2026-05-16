#!/bin/bash

# Ожидание готовности configSrv
echo "Waiting for configSrv to be ready..."
until docker compose exec -T configSrv mongosh --port 27017 --eval "db.adminCommand('ping')" &>/dev/null; do
  sleep 1
done

docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [{ _id: 0, host: "configSrv:27017" }]
});
EOF

# Ожидание готовности shard1
echo "Waiting for shard1 to be ready..."
until docker compose exec -T shard1 mongosh --port 27018 --eval "db.adminCommand('ping')" &>/dev/null; do
  sleep 1
done

docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1",
  members: [{ _id: 0, host: "shard1:27018" }]
});
EOF

# Ожидание готовности shard2
echo "Waiting for shard2 to be ready..."
until docker compose exec -T shard2 mongosh --port 27019 --eval "db.adminCommand('ping')" &>/dev/null; do
  sleep 1
done

docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
rs.initiate({
  _id: "shard2",
  members: [{ _id: 0, host: "shard2:27019" }]
});
EOF

# Ожидание готовности mongos_router
echo "Waiting for mongos_router to be ready..."
until docker compose exec -T mongos_router mongosh --port 27020 --eval "db.adminCommand('ping')" &>/dev/null; do
  sleep 1
done

docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1/shard1:27018");
sh.addShard("shard2/shard2:27019");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name": "hashed" });

use somedb
for (var i = 0; i < 1000; i++) db.helloDoc.insert({ age: i, name: "ly" + i });
db.helloDoc.countDocuments();
EOF
