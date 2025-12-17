#!/usr/bin/env bash
set -euo pipefail

echo ">> Waiting 5s for containers to settle..."
sleep 5

echo ">> Init config server"
docker compose exec -T configSrv mongosh --port 27017 --quiet <<'EOF' || true
try {
  rs.initiate({
    _id: "config_server",
    configsvr: true,
    members: [
      { _id: 0, host: "configSrv:27017" }
    ]
  })
} catch(e) { print(e) }
EOF

echo ">> Init shard1 (2 members)"
docker compose exec -T shard1a mongosh --port 27018 --quiet <<'EOF' || true
try {
  rs.initiate({
    _id: "shard1",
    members: [
      { _id: 0, host: "shard1a:27018" },
      { _id: 1, host: "shard1b:27018" }
    ]
  })
} catch(e) { print(e) }
EOF

echo ">> Init shard2 (2 members)"
docker compose exec -T shard2a mongosh --port 27019 --quiet <<'EOF' || true
try {
  rs.initiate({
    _id: "shard2",
    members: [
      { _id: 0, host: "shard2a:27019" },
      { _id: 1, host: "shard2b:27019" }
    ]
  })
} catch(e) { print(e) }
EOF

echo ">> Waiting for elections..."
sleep 5

echo ">> Add shards & enable sharding via mongos (instance 1)"
docker compose exec -T --index=1 mongos_router mongosh --port 27020 --quiet <<'EOF'
try { sh.addShard("shard1/shard1a:27018,shard1b:27018") } catch(e) { print(e) }
try { sh.addShard("shard2/shard2a:27019,shard2b:27019") } catch(e) { print(e) }

try { sh.enableSharding("somedb") } catch(e) { print(e) }
try { sh.shardCollection("somedb.helloDoc", { "name": "hashed" }) } catch(e) { print(e) }

use somedb
if (db.helloDoc.countDocuments() < 1000) {
  for (var i=0; i<1000; i++) db.helloDoc.insertOne({ age: i, name: "ly"+i })
}
db.helloDoc.countDocuments()
EOF

echo ">> Done."
