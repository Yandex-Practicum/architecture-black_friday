#!/bin/bash

set -e

echo "Initializing config server..."

docker exec configSrv mongosh --port 27017 --eval '
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv:27017" }
  ]
})
'
sleep 10

echo "Initializing shard1..."

docker exec shard1 mongosh --port 27018 --eval '
rs.initiate({
  _id: "shard1",
  members: [
    { _id: 0, host: "shard1:27018" },
    { _id: 1, host: "shard3:27021" },
    { _id: 2, host: "shard5:27024" }
  ]
})
'

echo "Initializing shard2..."

docker exec shard2 mongosh --port 27019 --eval '
rs.initiate({
  _id: "shard2",
  members: [
    { _id: 0, host: "shard2:27019" },
    { _id: 1, host: "shard4:27022" },
    { _id: 2, host: "shard6:27023" }
  ]
})
'

sleep 10
echo "Configuring mongos router..."

docker exec mongos_router mongosh --port 27020 --eval '
sh.addShard("shard1/shard1:27018");
sh.addShard("shard2/shard2:27019");

sh.enableSharding("somedb");

sh.shardCollection(
  "somedb.helloDoc",
  { name: "hashed" }
);

const dbS = db.getSiblingDB("somedb");

for (var i = 0; i < 1000; i++) {
  dbS.helloDoc.insertOne({
    age: i,
    name: "ly" + i
  });
}

print("Documents count: " + dbS.helloDoc.countDocuments());
'

echo "MongoDB cluster and Redis initialized successfully"