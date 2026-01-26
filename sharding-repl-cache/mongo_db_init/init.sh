#!/usr/bin/env bash
set -euo pipefail

#################################
# Config Server
#################################
mongosh --host configSvr --port 27019 << 'EOF'
try {
  rs.status()
  print("Config server replica set already initialized")
} catch (e) {
  rs.initiate({
    _id: "configSvr",
    configsvr: true,
    members: [{ _id: 0, host: "configSvr:27019" }]
  })
  print("Config server replica set initiated")
}
EOF

#################################
# Shard 1
#################################
mongosh --host shard1 --port 27018 << 'EOF'
try {
  rs.status()
  print("Shard1 replica set already initialized")
} catch (e) {
  rs.initiate({
    _id: "shard1",
    members: [{ _id: 0, host: "shard1:27018" }]
  })
  print("Shard1 replica set initiated")
}
EOF

#################################
# Shard 2
#################################
mongosh --host shard2 --port 27020 << 'EOF'
try {
  rs.status()
  print("Shard2 replica set already initialized")
} catch (e) {
  rs.initiate({
    _id: "shard2",
    members: [{ _id: 0, host: "shard2:27020" }]
  })
  print("Shard2 replica set initiated")
}
EOF

#################################
# Mongos router
#################################
mongosh --host mongodb1 --port 27017 << 'EOF'
const dbName = "somedb";
const collName = "helloDoc";
const ns = `${dbName}.${collName}`;

// add shards idempotently
const shards = db.getSiblingDB("config").shards.find().toArray().map(s => s._id);

if (!shards.includes("shard1")) {
  sh.addShard("shard1/shard1:27018");
  print("Shard1 added");
}

if (!shards.includes("shard2")) {
  sh.addShard("shard2/shard2:27020");
  print("Shard2 added");
}

// enable sharding on DB
const dbInfo = db.getSiblingDB("config")
  .databases
  .findOne({ _id: dbName });

if (!dbInfo || !dbInfo.partitioned) {
  sh.enableSharding(dbName);
  print(`Sharding enabled for database ${dbName}`);
} else {
  print(`Database ${dbName} already sharded`);
}

// ensure collection exists
const appDb = db.getSiblingDB(dbName);
if (!appDb.getCollectionNames().includes(collName)) {
  appDb.createCollection(collName);
  print(`Collection ${collName} created`);
}

// shard collection
const collInfo = db.getSiblingDB("config")
  .collections
  .findOne({ _id: ns });

if (!collInfo) {
  sh.shardCollection(ns, { name: "hashed" });
  print(`Collection ${ns} sharded`);
} else {
  print(`Collection ${ns} already sharded`);
}
EOF
