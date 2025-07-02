#!/bin/bash

set -e

echo "Step 1. Downloading docker images..."
docker pull mongo:6

echo "Step 2. Running configsvr, shard1 и shard2..."
docker compose up -d configsvr shard1 shard2

echo "waitng while containers up ..."
sleep 5

echo "Step 3. Init cfgRS (config server)..."
docker exec configsvr mongosh --eval '
rs.initiate({
  _id: "cfgRS",
  configsvr: true,
  members: [{ _id: 0, host: "configsvr:27017" }]
})' || echo "configsvr is already initialized"

echo "Step 4. Init shard1RS..."
docker exec shard1 mongosh --port 27018 --eval '
rs.initiate({
  _id: "shard1RS",
  members: [{ _id: 0, host: "shard1:27018" }]
})' || echo "shard1 is already initialized"

echo "Step 5. Init shard2RS..."
docker exec shard2 mongosh --port 27019 --eval '
rs.initiate({
  _id: "shard2RS",
  members: [{ _id: 0, host: "shard2:27019" }]
})' || echo "shard2 is already initialized"

echo "waiting for init replica sets..."
sleep 5

echo "Step 6. Run mongos..."
docker compose up -d mongos

echo "wainting for running mongos..."
sleep 5


echo "Step 7. Connect shards to mongos..."
docker exec mongos mongosh --eval '
sh.addShard("shard1RS/shard1:27018");
sh.addShard("shard2RS/shard2:27019");
sh.status();
'

echo "MongoDB shards are initialized!!!"

echo "Step 8. Insert test data into somedb.helloDoc..."

docker exec -i mongos mongosh <<EOF
use somedb
for (var i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({ age: i, name: "ly" + i });
}
EOF

echo "Test data inserted!"

echo "Step 9. Run API (pymongo_api)..."
docker compose up -d pymongo_api

echo "Application is available on http://localhost:8080"
