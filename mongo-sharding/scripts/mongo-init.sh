#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

docker compose up -d

wait_for_mongo() {
  local service="$1"
  local port="$2"

  until docker compose exec -T "$service" mongosh --port "$port" --quiet --eval "db.adminCommand({ ping: 1 }).ok" 2>/dev/null | grep -q "1"; do
    sleep 2
  done
}

wait_for_primary() {
  local service="$1"
  local port="$2"

  until docker compose exec -T "$service" mongosh --port "$port" --quiet --eval "db.hello().isWritablePrimary" 2>/dev/null | grep -q "true"; do
    sleep 2
  done
}

wait_for_mongo configSrv 27017
wait_for_mongo shard1 27018
wait_for_mongo shard2 27019

# A single config-server member is sufficient for this Task 2 development stand.
docker compose exec -T configSrv mongosh --port 27017 --quiet <<'EOF'
try {
  rs.status();
  print("config_server is already initialized");
} catch (error) {
  rs.initiate({
    _id: "config_server",
    configsvr: true,
    members: [{ _id: 0, host: "configSrv:27017" }]
  });
}
EOF

docker compose exec -T shard1 mongosh --port 27018 --quiet <<'EOF'
try {
  rs.status();
  print("shard1 is already initialized");
} catch (error) {
  rs.initiate({
    _id: "shard1",
    members: [{ _id: 0, host: "shard1:27018" }]
  });
}
EOF

docker compose exec -T shard2 mongosh --port 27019 --quiet <<'EOF'
try {
  rs.status();
  print("shard2 is already initialized");
} catch (error) {
  rs.initiate({
    _id: "shard2",
    members: [{ _id: 0, host: "shard2:27019" }]
  });
}
EOF

wait_for_primary configSrv 27017
wait_for_primary shard1 27018
wait_for_primary shard2 27019

until docker compose exec -T mongos_router mongosh --port 27020 --quiet --eval "db.adminCommand({ ping: 1 }).ok" 2>/dev/null | grep -q "1"; do
  sleep 2
done

docker compose exec -T mongos_router mongosh --port 27020 --quiet <<'EOF'
const configuredShards = db.adminCommand({ listShards: 1 }).shards;
if (!configuredShards.some((shard) => shard._id === "shard1")) {
  sh.addShard("shard1/shard1:27018");
}
if (!configuredShards.some((shard) => shard._id === "shard2")) {
  sh.addShard("shard2/shard2:27019");
}
sh.enableSharding("somedb");
try {
  sh.shardCollection("somedb.helloDoc", { name: "hashed" });
} catch (error) {
  print("helloDoc is already sharded");
}

const collection = db.getSiblingDB("somedb").helloDoc;
const existing = collection.countDocuments({});
for (let i = existing; i < 1000; i++) {
  collection.insertOne({ age: i, name: "ly" + i });
}
printjson({ total_documents: collection.countDocuments({}) });
EOF

echo "MongoDB sharding is initialized."
echo "Total documents:"
docker compose exec -T mongos_router mongosh --port 27020 --quiet --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments()'
echo "Documents on shard1:"
docker compose exec -T shard1 mongosh --port 27018 --quiet --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments()'
echo "Documents on shard2:"
docker compose exec -T shard2 mongosh --port 27019 --quiet --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments()'
