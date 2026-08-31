#!/bin/bash
set -e

docker compose up -d configSrv shard1 shard2

sleep 5

docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [{ _id: 0, host: "configSrv:27017" }]
})
EOF

sleep 5

docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1_set",
  members: [{ _id: 0, host: "shard1:27018" }]
})
EOF

sleep 5

docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
rs.initiate({
  _id: "shard2_set",
  members: [{ _id: 0, host: "shard2:27019" }]
})
EOF

sleep 5

docker compose up -d mongos_router pymongo_api

sleep 8

docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1_set/shard1:27018")
sh.addShard("shard2_set/shard2:27019")
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { "name": "hashed" })

use somedb
for (var i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({ age: i, name: "ly" + i })
}
EOF

echo "total:"
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo "shard1:"
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo "shard2:"
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
