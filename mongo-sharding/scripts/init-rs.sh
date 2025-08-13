#!/usr/bin/env bash
set -euo pipefail

echo "[init-rs] init config_server"
mongosh --host configSrv --port 27017 --quiet <<'EOF'
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [{ _id: 0, host: "configSrv:27017" }]
});
while (!rs.isMaster().ismaster) { sleep(100); }
EOF

echo "[init-rs] init shard1"
mongosh --host shard1 --port 27018 --quiet <<'EOF'
rs.initiate({
  _id: "shard1",
  members: [{ _id: 0, host: "shard1:27018" }]
});
while (!rs.isMaster().ismaster) { sleep(100); }
EOF

echo "[init-rs] init shard2"
mongosh --host shard2 --port 27019 --quiet <<'EOF'
rs.initiate({
  _id: "shard2",
  members: [{ _id: 0, host: "shard2:27019" }]
});
while (!rs.isMaster().ismaster) { sleep(100); }
EOF

echo "[init-rs] done"
