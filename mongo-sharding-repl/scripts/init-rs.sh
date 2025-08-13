#!/usr/bin/env bash
set -euo pipefail

echo "[init-rs] init config_server (single member RS)"
mongosh --host configSrv --port 27017 --quiet <<'EOF'
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [{ _id: 0, host: "configSrv:27017" }]
});
while (rs.status().ok !== 1) { sleep(200); }
EOF

echo "[init-rs] init shard1 (3 members)"
mongosh --host shard1-1 --port 27018 --quiet <<'EOF'
rs.initiate({
  _id: "shard1",
  members: [
    { _id: 0, host: "shard1-1:27018" },
    { _id: 1, host: "shard1-2:27018" },
    { _id: 2, host: "shard1-3:27018" }
  ]
});
while (rs.status().ok !== 1) { sleep(200); }
EOF

echo "[init-rs] init shard2 (3 members)"
mongosh --host shard2-1 --port 27019 --quiet <<'EOF'
rs.initiate({
  _id: "shard2",
  members: [
    { _id: 0, host: "shard2-1:27019" },
    { _id: 1, host: "shard2-2:27019" },
    { _id: 2, host: "shard2-3:27019" }
  ]
});
while (rs.status().ok !== 1) { sleep(200); }
EOF

echo "[init-rs] done"
