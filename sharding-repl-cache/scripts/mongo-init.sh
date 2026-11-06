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

for target in \
  "configSrv 27017" \
  "shard1-1 27018" "shard1-2 27019" "shard1-3 27020" \
  "shard2-1 27021" "shard2-2 27022" "shard2-3 27023"; do
  read -r service port <<< "$target"
  wait_for_mongo "$service" "$port"
done

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

docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<'EOF'
try {
  rs.status();
  print("shard1 is already initialized");
} catch (error) {
  rs.initiate({
    _id: "shard1",
    members: [
      { _id: 0, host: "shard1-1:27018" },
      { _id: 1, host: "shard1-2:27019" },
      { _id: 2, host: "shard1-3:27020" }
    ]
  });
}
EOF

docker compose exec -T shard2-1 mongosh --port 27021 --quiet <<'EOF'
try {
  rs.status();
  print("shard2 is already initialized");
} catch (error) {
  rs.initiate({
    _id: "shard2",
    members: [
      { _id: 0, host: "shard2-1:27021" },
      { _id: 1, host: "shard2-2:27022" },
      { _id: 2, host: "shard2-3:27023" }
    ]
  });
}
EOF

wait_for_primary shard1-1 27018
wait_for_primary shard2-1 27021

until docker compose exec -T mongos_router mongosh --port 27024 --quiet --eval "db.adminCommand({ ping: 1 }).ok" 2>/dev/null | grep -q "1"; do
  sleep 2
done

docker compose exec -T mongos_router mongosh --port 27024 --quiet <<'EOF'
const configuredShards = db.adminCommand({ listShards: 1 }).shards;
if (!configuredShards.some((shard) => shard._id === "shard1")) {
  sh.addShard("shard1/shard1-1:27018,shard1-2:27019,shard1-3:27020");
}
if (!configuredShards.some((shard) => shard._id === "shard2")) {
  sh.addShard("shard2/shard2-1:27021,shard2-2:27022,shard2-3:27023");
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

echo "MongoDB sharding, replication, and Redis caching are initialized."
echo "Total documents:"
docker compose exec -T mongos_router mongosh --port 27024 --quiet --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments()'
echo "Documents on shard1:"
docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments()'
echo "Documents on shard2:"
docker compose exec -T shard2-1 mongosh --port 27021 --quiet --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments()'
echo "Replica members on shard1:"
docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval 'rs.status().members.length'
echo "Replica members on shard2:"
docker compose exec -T shard2-1 mongosh --port 27021 --quiet --eval 'rs.status().members.length'
