#!/usr/bin/env bash

set -Eeuo pipefail

wait_for_mongo() {
  local service="$1"
  local port="$2"

  printf 'Ожидание сервиса %s...' "$service"
  for _ in $(seq 1 60); do
    if docker compose exec -T "$service" mongosh --port "$port" --quiet \
      --eval 'quit(db.adminCommand({ ping: 1 }).ok ? 0 : 1)' >/dev/null 2>&1; then
      printf ' готово\n'
      return 0
    fi
    sleep 2
  done

  printf ' ошибка\n' >&2
  return 1
}

wait_for_replica_set() {
  local service="$1"
  local port="$2"
  local expected_members="$3"

  printf 'Ожидание replica set через %s...' "$service"
  for _ in $(seq 1 60); do
    if docker compose exec -T "$service" mongosh --port "$port" --quiet --eval "
      try {
        const status = rs.status();
        const healthy = status.members.filter(member => member.health === 1).length;
        const primary = status.members.filter(member => member.stateStr === 'PRIMARY').length;
        quit(healthy === ${expected_members} && primary === 1 ? 0 : 1);
      } catch (error) {
        quit(1);
      }
    " >/dev/null 2>&1; then
      printf ' готово\n'
      return 0
    fi
    sleep 2
  done

  printf ' ошибка\n' >&2
  return 1
}

initialize_config_server() {
  docker compose exec -T configsvr mongosh --port 27019 --quiet --file /dev/stdin <<'EOF'
const commandWorked = result => {
  if (!result || result.ok !== 1) {
    throw new Error("MongoDB command failed: " + JSON.stringify(result));
  }
  return result;
};

try {
  const status = rs.status();
  print(status.set + " уже настроен");
} catch (error) {
  if (error.code !== 94 && error.codeName !== "NotYetInitialized") {
    throw error;
  }
  commandWorked(rs.initiate({
    _id: "config-rs",
    configsvr: true,
    members: [{ _id: 0, host: "configsvr:27019" }]
  }));
  print("config-rs настроен");
}
EOF
}

initialize_shards() {
  docker compose exec -T shard1 mongosh --port 27018 --quiet --file /dev/stdin <<'EOF'
const commandWorked = result => {
  if (!result || result.ok !== 1) {
    throw new Error("MongoDB command failed: " + JSON.stringify(result));
  }
  return result;
};

try {
  const status = rs.status();
  print(status.set + " уже настроен");
} catch (error) {
  if (error.code !== 94 && error.codeName !== "NotYetInitialized") {
    throw error;
  }
  commandWorked(rs.initiate({
    _id: "shard1-rs",
    members: [{ _id: 0, host: "shard1:27018" }]
  }));
  print("shard1-rs настроен");
}
EOF

  docker compose exec -T shard2 mongosh --port 27018 --quiet --file /dev/stdin <<'EOF'
const commandWorked = result => {
  if (!result || result.ok !== 1) {
    throw new Error("MongoDB command failed: " + JSON.stringify(result));
  }
  return result;
};

try {
  const status = rs.status();
  print(status.set + " уже настроен");
} catch (error) {
  if (error.code !== 94 && error.codeName !== "NotYetInitialized") {
    throw error;
  }
  commandWorked(rs.initiate({
    _id: "shard2-rs",
    members: [{ _id: 0, host: "shard2:27018" }]
  }));
  print("shard2-rs настроен");
}
EOF
}

configure_sharding_and_data() {
  docker compose exec -T mongos mongosh --port 27017 --quiet --file /dev/stdin <<'EOF'
const commandWorked = result => {
  if (!result || result.ok !== 1) {
    throw new Error("MongoDB command failed: " + JSON.stringify(result));
  }
  return result;
};

const adminDb = db.getSiblingDB("admin");
const currentShards = adminDb.runCommand({ listShards: 1 });
commandWorked(currentShards);
const shardNames = new Set(currentShards.shards.map(shard => shard._id));

if (!shardNames.has("shard1")) {
  commandWorked(adminDb.runCommand({
    addShard: "shard1-rs/shard1:27018",
    name: "shard1"
  }));
}

if (!shardNames.has("shard2")) {
  commandWorked(adminDb.runCommand({
    addShard: "shard2-rs/shard2:27018",
    name: "shard2"
  }));
}

commandWorked(adminDb.runCommand({ enableSharding: "somedb" }));

const configDb = db.getSiblingDB("config");
const namespace = "somedb.helloDoc";
const shardedCollection = configDb.collections.findOne({
  _id: namespace,
  dropped: { $ne: true }
});

if (!shardedCollection) {
  commandWorked(adminDb.runCommand({
    shardCollection: namespace,
    key: { _id: "hashed" }
  }));
}

const collection = db.getSiblingDB("somedb").helloDoc;
const operations = [];
for (let index = 0; index < 1000; index += 1) {
  operations.push({
    updateOne: {
      filter: { _id: index },
      update: { $set: { age: index, name: "ly" + index } },
      upsert: true
    }
  });
}
collection.bulkWrite(operations, { ordered: false });

print("Всего документов: " + collection.countDocuments({}));
adminDb.runCommand({ listShards: 1 }).shards.forEach(shard => {
  print(shard._id + ": " + shard.host);
});
EOF
}

print_shard_statistics() {
  for shard in shard1 shard2; do
    docker compose exec -T "$shard" mongosh --port 27018 --quiet --eval '
      const status = rs.status();
      const count = db.getSiblingDB("somedb").helloDoc.countDocuments({});
      print(status.set + ": " + count + " документов, " + status.members.length + " реплика");
    '
  done
}

wait_for_mongo configsvr 27019
wait_for_mongo shard1 27018
wait_for_mongo shard2 27018
initialize_config_server
initialize_shards
wait_for_replica_set configsvr 27019 1
wait_for_replica_set shard1 27018 1
wait_for_replica_set shard2 27018 1
wait_for_mongo mongos 27017
configure_sharding_and_data
print_shard_statistics

printf 'Инициализация шардирования завершена\n'
