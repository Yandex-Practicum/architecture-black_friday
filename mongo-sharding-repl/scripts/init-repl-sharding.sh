#!/bin/bash
set -euo pipefail

until docker compose exec -T mongos mongosh --port 27017 --quiet --eval 'db.runCommand({ ping: 1 }).ok' >/dev/null 2>&1; do
  sleep 1
done

docker compose exec -T configsvr mongosh --port 27019 --quiet <<'EOF'
try {
  rs.status()
} catch (e) {
  rs.initiate({
    _id: "configReplSet",
    configsvr: true,
    members: [{ _id: 0, host: "configsvr:27019" }]
  })
}
EOF

docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<'EOF'
try {
  rs.status()
} catch (e) {
  rs.initiate({
    _id: "shard1ReplSet",
    members: [
      { _id: 0, host: "shard1-1:27018" },
      { _id: 1, host: "shard1-2:27018" },
      { _id: 2, host: "shard1-3:27018" }
    ]
  })
}
EOF

docker compose exec -T shard2-1 mongosh --port 27018 --quiet <<'EOF'
try {
  rs.status()
} catch (e) {
  rs.initiate({
    _id: "shard2ReplSet",
    members: [
      { _id: 0, host: "shard2-1:27018" },
      { _id: 1, host: "shard2-2:27018" },
      { _id: 2, host: "shard2-3:27018" }
    ]
  })
}
EOF

docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
try { sh.addShard("shard1ReplSet/shard1-1:27018,shard1-2:27018,shard1-3:27018") } catch (e) {}
try { sh.addShard("shard2ReplSet/shard2-1:27018,shard2-2:27018,shard2-3:27018") } catch (e) {}
try { sh.enableSharding("somedb") } catch (e) {}
try { sh.shardCollection("somedb.helloDoc", { "_id": "hashed" }) } catch (e) {}
EOF
