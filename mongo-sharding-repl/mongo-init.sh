#!/usr/bin/env bash
set -e

echo "starting containers"
docker compose up -d

echo "waiting for nodes to start"
sleep 20

echo "init config server"
docker compose exec -T configSrv mongosh --port 27019 --quiet <<'EOF'
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [{ _id: 0, host: "configSrv:27019" }]
})
EOF

echo "init shard1"
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<'EOF'
rs.initiate({
  _id: "shard1",
  members: [
    { _id: 0, host: "shard1-1:27018" },
    { _id: 1, host: "shard1-2:27018" },
    { _id: 2, host: "shard1-3:27018" }
  ]
})
EOF

echo "init shard2"
docker compose exec -T shard2-1 mongosh --port 27018 --quiet <<'EOF'
rs.initiate({
  _id: "shard2",
  members: [
    { _id: 0, host: "shard2-1:27018" },
    { _id: 1, host: "shard2-2:27018" },
    { _id: 2, host: "shard2-3:27018" }
  ]
})
EOF

echo "waiting for primary election"
sleep 20

echo "add shards and enable sharding"
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
sh.addShard("shard1/shard1-1:27018,shard1-2:27018,shard1-3:27018")
sh.addShard("shard2/shard2-1:27018,shard2-2:27018,shard2-3:27018")
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { _id: "hashed" })
EOF

echo "inserting 1000 documents"
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
for (let i = 0; i < 1000; i++) db.helloDoc.insertOne({ age: i, name: "ly" + i })
EOF
