#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

wait_for_mongo() {
    local service="$1"
    local port="$2"

    for _ in $(seq 1 60); do
        if docker compose exec -T "$service" mongosh --port "$port" --quiet \
            --eval 'quit(db.adminCommand({ping: 1}).ok ? 0 : 1)' >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
    done

    echo "MongoDB service $service did not become ready" >&2
    return 1
}

wait_for_primary() {
    local service="$1"
    local port="$2"

    for _ in $(seq 1 60); do
        if docker compose exec -T "$service" mongosh --port "$port" --quiet \
            --eval 'quit(db.hello().isWritablePrimary ? 0 : 1)' >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
    done

    echo "Replica set on $service did not elect a primary" >&2
    return 1
}

echo "Waiting for MongoDB services..."
wait_for_mongo config-srv 27017
for service in shard1-1 shard1-2 shard1-3; do
    wait_for_mongo "$service" 27018
done
for service in shard2-1 shard2-2 shard2-3; do
    wait_for_mongo "$service" 27019
done

docker compose exec -T config-srv mongosh --port 27017 --quiet <<'EOF'
try {
    rs.status();
    print("config-rs is already initialized");
} catch (error) {
    if (error.code === 94 || error.codeName === "NotYetInitialized") {
        printjson(rs.initiate({
            _id: "config-rs",
            configsvr: true,
            members: [{_id: 0, host: "config-srv:27017"}]
        }));
    } else {
        throw error;
    }
}
EOF

docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<'EOF'
try {
    rs.status();
    print("shard1-rs is already initialized");
} catch (error) {
    if (error.code === 94 || error.codeName === "NotYetInitialized") {
        printjson(rs.initiate({
            _id: "shard1-rs",
            members: [
                {_id: 0, host: "shard1-1:27018"},
                {_id: 1, host: "shard1-2:27018"},
                {_id: 2, host: "shard1-3:27018"}
            ]
        }));
    } else {
        throw error;
    }
}
EOF

docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<'EOF'
try {
    rs.status();
    print("shard2-rs is already initialized");
} catch (error) {
    if (error.code === 94 || error.codeName === "NotYetInitialized") {
        printjson(rs.initiate({
            _id: "shard2-rs",
            members: [
                {_id: 0, host: "shard2-1:27019"},
                {_id: 1, host: "shard2-2:27019"},
                {_id: 2, host: "shard2-3:27019"}
            ]
        }));
    } else {
        throw error;
    }
}
EOF

wait_for_primary config-srv 27017
wait_for_primary shard1-1 27018
wait_for_primary shard2-1 27019
wait_for_mongo mongos-router 27020

docker compose exec -T mongos-router mongosh --port 27020 --quiet <<'EOF'
const adminDb = db.getSiblingDB("admin");
const configDb = db.getSiblingDB("config");
const shardIds = new Set(adminDb.runCommand({listShards: 1}).shards.map((shard) => shard._id));

if (!shardIds.has("shard1-rs")) {
    printjson(sh.addShard("shard1-rs/shard1-1:27018,shard1-2:27018,shard1-3:27018"));
}
if (!shardIds.has("shard2-rs")) {
    printjson(sh.addShard("shard2-rs/shard2-1:27019,shard2-2:27019,shard2-3:27019"));
}

if (!configDb.databases.findOne({_id: "somedb"})) {
    printjson(adminDb.runCommand({enableSharding: "somedb"}));
}
if (!configDb.collections.findOne({_id: "somedb.helloDoc"})) {
    printjson(adminDb.runCommand({
        shardCollection: "somedb.helloDoc",
        key: {name: "hashed"},
        numInitialChunks: 4
    }));
}

const collection = db.getSiblingDB("somedb").helloDoc;
const currentCount = collection.countDocuments();
if (currentCount < 1000) {
    const documents = [];
    for (let index = currentCount; index < 1000; index += 1) {
        documents.push({age: index, name: `ly${index}`});
    }
    const insertResult = collection.insertMany(documents);
    printjson({insertedDocuments: Object.keys(insertResult.insertedIds).length});
}

printjson({totalDocuments: collection.countDocuments()});
printjson(adminDb.runCommand({listShards: 1}).shards);
EOF

echo "Documents on shard1: $(docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments()')"
echo "Documents on shard2: $(docker compose exec -T shard2-1 mongosh --port 27019 --quiet --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments()')"

docker compose exec -T shard1-1 mongosh --port 27018 --quiet \
    --eval 'printjson(rs.status().members.map(({name, stateStr}) => ({name, stateStr})))'
docker compose exec -T shard2-1 mongosh --port 27019 --quiet \
    --eval 'printjson(rs.status().members.map(({name, stateStr}) => ({name, stateStr})))'

echo "Sharding, replication and cache initialization completed"
