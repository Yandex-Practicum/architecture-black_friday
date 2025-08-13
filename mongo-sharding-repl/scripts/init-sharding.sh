#!/usr/bin/env bash
set -euo pipefail

echo "[init-sharding] add shards via mongos"
mongosh --host mongos_router --port 27020 --quiet <<'EOF'
sh.addShard("shard1/shard1-1:27018,shard1-2:27018,shard1-3:27018");
sh.addShard("shard2/shard2-1:27019,shard2-2:27019,shard2-3:27019");

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { name: "hashed" });

use somedb;
const need = 1000;
const have = db.helloDoc.countDocuments();
for (let i = have; i < need; i++) {
  db.helloDoc.insertOne({ age: i, name: "ly" + i });
}
print("Total docs:", db.helloDoc.countDocuments());
db.helloDoc.getShardDistribution();
EOF

echo "[init-sharding] done"
