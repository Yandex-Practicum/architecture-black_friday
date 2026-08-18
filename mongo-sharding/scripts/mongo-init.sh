#!/bin/bash

set -e

echo "Waiting for mongos_router to be ready..."
sleep 15

echo "Initializing Config Servers..."
mongosh --host config_server_1:27019 --quiet <<EOF
rs.initiate({
  _id: "cfg_replset",
  members: [
    { _id: 0, host: "config_server_1:27019" },
    { _id: 1, host: "config_server_2:27019" },
    { _id: 2, host: "config_server_3:27019" }
  ]
})
EOF

echo "Initializing Shard 1..."
mongosh --host shard1:27018 --quiet <<EOF
rs.initiate({
  _id: "shard1",
  members: [
    { _id: 0, host: "shard1:27018" }
  ]
})
EOF

echo "Initializing Shard 2..."
mongosh --host shard2:27019 --quiet <<EOF
rs.initiate({
  _id: "shard2",
  members: [
    { _id: 0, host: "shard2:27019" }
  ]
})
EOF

echo "Waiting for replica sets to stabilize..."
sleep 15

echo "Adding shards and configuring..."
mongosh --host mongos_router:27017 --quiet <<EOF
sh.addShard("shard1/shard1:27018")
sh.addShard("shard2/shard2:27019")

use somedb
sh.enableSharding("somedb")
db.helloDoc.createIndex({ "_id": "hashed" })
sh.shardCollection("somedb.helloDoc", { "_id": "hashed" })

for (var i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({
    _id: i,
    age: i,
    name: "ly" + i,
    createdAt: new Date()
  })
}
EOF

echo "Init completed successfully."