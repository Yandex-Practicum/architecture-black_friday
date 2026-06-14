#!/usr/bin/env bash
set -euo pipefail

wait_for_mongo() {
  local service="$1"
  until docker compose exec -T "$service" mongosh --port 27017 --quiet --eval 'db.adminCommand({ping: 1}).ok' >/dev/null 2>&1; do
    sleep 2
  done
}

for service in configSrv shard1-1 shard1-2 shard1-3 shard2-1 shard2-2 shard2-3; do
  wait_for_mongo "$service"
done

docker compose exec -T configSrv mongosh --port 27017 --quiet <<'EOF'
try {
  const status = rs.status();
} catch (error) {
  rs.initiate({_id: "configRs", configsvr: true, members: [{_id: 0, host: "configSrv:27017"}]});
}
EOF

docker compose exec -T shard1-1 mongosh --port 27017 --quiet <<'EOF'
try {
  const status = rs.status();
} catch (error) {
  rs.initiate({
    _id: "shard1Rs",
    members: [
      {_id: 0, host: "shard1-1:27017"},
      {_id: 1, host: "shard1-2:27017"},
      {_id: 2, host: "shard1-3:27017"}
    ]
  });
}
EOF

docker compose exec -T shard2-1 mongosh --port 27017 --quiet <<'EOF'
try {
  const status = rs.status();
} catch (error) {
  rs.initiate({
    _id: "shard2Rs",
    members: [
      {_id: 0, host: "shard2-1:27017"},
      {_id: 1, host: "shard2-2:27017"},
      {_id: 2, host: "shard2-3:27017"}
    ]
  });
}
EOF

sleep 8
wait_for_mongo mongos

docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
const shardIds = db.adminCommand({listShards: 1}).shards.map((shard) => shard._id);
if (!shardIds.includes("shard1Rs")) {
  sh.addShard("shard1Rs/shard1-1:27017,shard1-2:27017,shard1-3:27017");
}
if (!shardIds.includes("shard2Rs")) {
  sh.addShard("shard2Rs/shard2-1:27017,shard2-2:27017,shard2-3:27017");
}

sh.enableSharding("somedb");
const collection = db.getSiblingDB("somedb").helloDoc;
const config = db.getSiblingDB("config");
if (!config.collections.findOne({_id: "somedb.helloDoc", dropped: false})) {
  sh.shardCollection("somedb.helloDoc", {_id: "hashed"}, false, {numInitialChunks: 8});
}

for (let i = 0; i < 1200; i++) {
  collection.updateOne({_id: i}, {$set: {age: i, name: "user-" + i}}, {upsert: true});
}

printjson({
  total_documents: collection.countDocuments({}),
  shard_distribution: collection.getShardDistribution(),
  shards: db.adminCommand({listShards: 1}).shards
});
EOF
