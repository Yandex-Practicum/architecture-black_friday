#!/usr/bin/env bash
set -euo pipefail

echo "[init-sharding] add shards via mongos"
mongosh --host mongos_router --port 27020 --quiet <<'EOF'
sh.addShard("shard1/shard1:27018");
sh.addShard("shard2/shard2:27019");

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { name: "hashed" });

use somedb;
for (let i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({ age: i, name: "ly" + i });
}
print("Total:", db.helloDoc.countDocuments());
EOF

echo "[init-sharding] done"
