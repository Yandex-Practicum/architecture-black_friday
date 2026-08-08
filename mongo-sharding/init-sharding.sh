#!/bin/sh

set -eu

compose() {
    if docker compose version >/dev/null 2>&1; then
        docker compose "$@"
    else
        docker-compose "$@"
    fi
}

wait_for_mongo() {
    service="$1"
    port="$2"

    until compose exec -T "$service" mongosh --port "$port" --quiet \
        --eval 'db.adminCommand({ ping: 1 }).ok' 2>/dev/null | grep -q 1; do
        echo "Waiting for $service:$port..."
        sleep 1
    done
}

wait_for_primary() {
    service="$1"
    port="$2"

    until compose exec -T "$service" mongosh --port "$port" --quiet \
        --eval 'db.hello().isWritablePrimary' 2>/dev/null | grep -q true; do
        echo "Waiting for replica set on $service:$port..."
        sleep 1
    done
}

wait_for_mongo configSrv 27019
wait_for_mongo shard1 27018
wait_for_mongo shard2 27018

compose exec -T configSrv mongosh --port 27019 --quiet <<'EOF'
try {
    void rs.status()
} catch (error) {
    rs.initiate({
        _id: "config-rs",
        configsvr: true,
        members: [{ _id: 0, host: "configSrv:27019" }]
    })
}
EOF

compose exec -T shard1 mongosh --port 27018 --quiet <<'EOF'
try {
    void rs.status()
} catch (error) {
    rs.initiate({
        _id: "shard1-rs",
        members: [{ _id: 0, host: "shard1:27018" }]
    })
}
EOF

compose exec -T shard2 mongosh --port 27018 --quiet <<'EOF'
try {
    void rs.status()
} catch (error) {
    rs.initiate({
        _id: "shard2-rs",
        members: [{ _id: 0, host: "shard2:27018" }]
    })
}
EOF

wait_for_primary configSrv 27019
wait_for_primary shard1 27018
wait_for_primary shard2 27018
wait_for_mongo mongos 27017

compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
const configDb = db.getSiblingDB("config")
if (!configDb.shards.findOne({ _id: "shard1-rs" })) {
    sh.addShard("shard1-rs/shard1:27018")
}
if (!configDb.shards.findOne({ _id: "shard2-rs" })) {
    sh.addShard("shard2-rs/shard2:27018")
}

sh.enableSharding("somedb")
const collection = db.getSiblingDB("somedb").helloDoc
const collectionMetadata = configDb.collections.findOne({
    _id: "somedb.helloDoc",
    dropped: { $ne: true }
})
if (!collectionMetadata) {
    sh.shardCollection("somedb.helloDoc", { name: "hashed" })
}

void collection.deleteMany({})
const users = Array.from({ length: 1000 }, (_, index) => ({
    age: index,
    name: `ly${index}`
}))
void collection.insertMany(users)

print(`Total documents: ${collection.countDocuments()}`)
print(collection.getShardDistribution())
EOF