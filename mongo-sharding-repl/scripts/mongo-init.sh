#!/usr/bin/env bash
set -e

docker compose exec -T configSrv mongosh --port 27017 --quiet <<'EOF'
try {
  if (rs.status().ok === 1) { print("CSRS уже инициализирован"); }
} catch (e) {
  rs.initiate({
    _id: "config_server",
    configsvr: true,
    members: [{ _id: 0, host: "configSrv:27017" }]
  });
  print("CSRS инициализирован");
}
EOF

docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<'EOF'
try {
  if (rs.status().ok === 1) { print("shard1 уже инициализирован"); }
} catch (e) {
  rs.initiate({
    _id: "shard1",
    members: [
      { _id: 0, host: "shard1-1:27018", priority: 2 },
      { _id: 1, host: "shard1-2:27018", priority: 1 },
      { _id: 2, host: "shard1-3:27018", priority: 1 }
    ]
  });
  print("shard1 инициализирован");
}
EOF

docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<'EOF'
try {
  if (rs.status().ok === 1) { print("shard2 уже инициализирован"); }
} catch (e) {
  rs.initiate({
    _id: "shard2",
    members: [
      { _id: 0, host: "shard2-1:27019", priority: 2 },
      { _id: 1, host: "shard2-2:27019", priority: 1 },
      { _id: 2, host: "shard2-3:27019", priority: 1 }
    ]
  });
  print("shard2 инициализирован");
}
EOF

docker compose restart mongo_router
sleep 15

docker compose exec -T mongo_router mongosh --port 27020 --quiet <<'EOF'
function safeAddShard(s) {
  try { printjson(sh.addShard(s)); } catch (e) { print(e); }
}

safeAddShard("shard1/shard1-1:27018,shard1-2:27018,shard1-3:27018");
safeAddShard("shard2/shard2-1:27019,shard2-2:27019,shard2-3:27019");

try { sh.enableSharding("somedb"); } catch (e) { print(e); }
try { sh.shardCollection("somedb.helloDoc", { name: "hashed" }); } catch (e) { print(e); }

use somedb;
const cnt = db.helloDoc.countDocuments();
if (cnt === 0) {
  for (let i = 0; i < 1000; i++) {
    db.helloDoc.insert({ age: i, name: "ly" + i });
  }
}
print("docs count:", db.helloDoc.countDocuments());
printjson(sh.status());
EOF

echo "The end!"
