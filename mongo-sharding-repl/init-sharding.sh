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
    attempts=0

    until compose exec -T "$service" mongosh --port "$port" --quiet \
        --eval 'db.adminCommand({ ping: 1 }).ok' 2>/dev/null | grep -q 1; do
        attempts=$((attempts + 1))
        if [ "$attempts" -ge 120 ]; then
            echo "Timed out waiting for $service:$port" >&2
            return 1
        fi
        echo "Waiting for $service:$port..."
        sleep 1
    done
}

wait_for_primary() {
    service="$1"
    port="$2"
    attempts=0

    until compose exec -T "$service" mongosh --port "$port" --quiet \
        --eval 'rs.status().members.some((member) => member.stateStr === "PRIMARY")' \
        2>/dev/null | grep -q true; do
        attempts=$((attempts + 1))
        if [ "$attempts" -ge 120 ]; then
            echo "Timed out waiting for a primary in the $service replica set" >&2
            return 1
        fi
        echo "Waiting for a primary in the $service replica set..."
        sleep 1
    done
}

wait_for_members() {
    service="$1"
    port="$2"
    expected="$3"
    attempts=0

    until compose exec -T "$service" mongosh --port "$port" --quiet \
        --eval 'rs.status().members.filter((member) => member.health === 1).length' \
        2>/dev/null | grep -q "^${expected}$"; do
        attempts=$((attempts + 1))
        if [ "$attempts" -ge 120 ]; then
            echo "Timed out waiting for $expected healthy members in $service" >&2
            return 1
        fi
        echo "Waiting for $expected healthy members in $service replica set..."
        sleep 1
    done
}

wait_for_mongo configSrv 27019

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

wait_for_primary configSrv 27019

for service in shard1-1 shard1-2 shard1-3 shard2-1 shard2-2 shard2-3; do
    wait_for_mongo "$service" 27018
done

compose exec -T shard1-1 mongosh --port 27018 --quiet <<'EOF'
try {
    void rs.status()
} catch (error) {
    rs.initiate({
        _id: "shard1-rs",
        members: [
            { _id: 0, host: "shard1-1:27018" },
            { _id: 1, host: "shard1-2:27018" },
            { _id: 2, host: "shard1-3:27018" }
        ]
    })
}
EOF

compose exec -T shard2-1 mongosh --port 27018 --quiet <<'EOF'
try {
    void rs.status()
} catch (error) {
    rs.initiate({
        _id: "shard2-rs",
        members: [
            { _id: 0, host: "shard2-1:27018" },
            { _id: 1, host: "shard2-2:27018" },
            { _id: 2, host: "shard2-3:27018" }
        ]
    })
}
EOF

wait_for_primary shard1-1 27018
wait_for_primary shard2-1 27018
wait_for_members shard1-1 27018 3
wait_for_members shard2-1 27018 3
wait_for_mongo mongos 27017

compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
const configDb = db.getSiblingDB("config")
if (!configDb.shards.findOne({ _id: "shard1-rs" })) {
    sh.addShard("shard1-rs/shard1-1:27018,shard1-2:27018,shard1-3:27018")
}
if (!configDb.shards.findOne({ _id: "shard2-rs" })) {
    sh.addShard("shard2-rs/shard2-1:27018,shard2-2:27018,shard2-3:27018")
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

compose exec -T shard1-1 mongosh --port 27018 --quiet \
    --eval 'print(`shard1-rs replicas: ${rs.status().members.length}`)'
compose exec -T shard2-1 mongosh --port 27018 --quiet \
    --eval 'print(`shard2-rs replicas: ${rs.status().members.length}`)'