#!/bin/bash

echo "Initializing Config Server replica set..."
docker compose exec -T configSrv1 mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv1:27017" },
    { _id: 1, host: "configSrv2:27017" },
    { _id: 2, host: "configSrv3:27017" }
  ]
})
EOF
sleep 10

echo "Initializing Shard 1 replica set..."
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1ReplSet",
  members: [
    { _id: 0, host: "shard1-1:27018" },
    { _id: 1, host: "shard1-2:27018" },
    { _id: 2, host: "shard1-3:27018" }
  ]
})
EOF
sleep 10

echo "Initializing Shard 2 replica set..."
docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
rs.initiate({
  _id: "shard2ReplSet",
  members: [
    { _id: 0, host: "shard2-1:27019" },
    { _id: 1, host: "shard2-2:27019" },
    { _id: 2, host: "shard2-3:27019" }
  ]
})
EOF
sleep 10

echo "Adding shards to cluster..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
sh.addShard("shard1ReplSet/shard1-1:27018,shard1-2:27018,shard1-3:27018")
sh.addShard("shard2ReplSet/shard2-1:27019,shard2-2:27019,shard2-3:27019")
EOF

echo "Enabling sharding..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
sh.enableSharding("somedb")
use somedb
db.createCollection("helloDoc")
sh.shardCollection("somedb.helloDoc", { _id: "hashed" })
EOF

echo "Inserting test data..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
use somedb
for(var i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({age: i, name: "ly" + i})
}
EOF

echo "Done! Stats:"
echo -n "Total: "
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo -n "Shard 1: "
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo -n "Shard 2: "
docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo -n "Replicas per shard: "
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.status().members.length
EOF
