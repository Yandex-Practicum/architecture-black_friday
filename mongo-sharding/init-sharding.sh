#!/usr/bin/env bash
set -euo pipefail

# =========================
# Config (можно менять)
# =========================
DB_NAME="${DB_NAME:-somedb}"
COLL_NAME="${COLL_NAME:-helloDoc}"
DOCS="${DOCS:-2000}"              # сколько документов заливать в конце
SHARD_KEY_TYPE="${SHARD_KEY_TYPE:-hashed}"  # hashed или 1 (range), но тут используем hashed по _id
DROP_COLLECTION="${DROP_COLLECTION:-true}"  # true/false: дропать коллекцию перед шардированием

# Replica set names / hosts
CFG_RS="configReplSet"
CFG_HOST="configsvr:27019"

S1_RS="shard1ReplSet"
S1_HOST="shard1:27018"

S2_RS="shard2ReplSet"
S2_HOST="shard2:27018"

# =========================
# Helpers
# =========================
log() { echo -e "\n==> $*"; }

dc() { docker compose "$@"; }

exec_mongo() {
  # usage: exec_mongo <service> <port> <js>
  local svc="$1"
  local port="$2"
  local js="$3"
  dc exec -T "$svc" mongosh --port "$port" --quiet --eval "$js"
}

wait_mongo() {
  # usage: wait_mongo <service> <port>
  local svc="$1"
  local port="$2"
  log "Waiting for $svc:$port to be ready..."
  for i in {1..60}; do
    if dc exec -T "$svc" mongosh --port "$port" --quiet --eval "db.runCommand({ping:1}).ok" >/dev/null 2>&1; then
      log "$svc is ready."
      return 0
    fi
    sleep 1
  done
  echo "ERROR: $svc did not become ready in time" >&2
  return 1
}

# =========================
# Start containers
# =========================
log "Starting stack (docker compose up -d --build)"
dc up -d --build

# Wait for mongo processes
wait_mongo configsvr 27019
wait_mongo shard1 27018
wait_mongo shard2 27018

# =========================
# 1) Initiate config replica set
# =========================
log "Init Config RS ($CFG_RS) if needed"
exec_mongo configsvr 27019 "
try {
  const st = rs.status();
  if (st.ok === 1) {
    print('Config RS already initiated');
  } else {
    throw new Error('status not ok');
  }
} catch (e) {
  print('Initiating Config RS...');
  rs.initiate({
    _id: '$CFG_RS',
    configsvr: true,
    members: [{ _id: 0, host: '$CFG_HOST' }]
  });
}
"

# Wait mongos again now that config RS exists
wait_mongo mongos 27017

# =========================
# 2) Initiate shard replica sets
# =========================
log "Init Shard1 RS ($S1_RS) if needed"
exec_mongo shard1 27018 "
try {
  const st = rs.status();
  if (st.ok === 1) {
    print('Shard1 RS already initiated');
  } else {
    throw new Error('status not ok');
  }
} catch (e) {
  print('Initiating Shard1 RS...');
  rs.initiate({
    _id: '$S1_RS',
    members: [{ _id: 0, host: '$S1_HOST' }]
  });
}
"

log "Init Shard2 RS ($S2_RS) if needed"
exec_mongo shard2 27018 "
try {
  const st = rs.status();
  if (st.ok === 1) {
    print('Shard2 RS already initiated');
  } else {
    throw new Error('status not ok');
  }
} catch (e) {
  print('Initiating Shard2 RS...');
  rs.initiate({
    _id: '$S2_RS',
    members: [{ _id: 0, host: '$S2_HOST' }]
  });
}
"

# =========================
# 3) Add shards to cluster (mongos)
# =========================
log "Add shards to cluster (idempotent)"
exec_mongo mongos 27017 "
const shards = db.getSiblingDB('config').shards.find().toArray().map(s => s._id);
if (!shards.includes('$S1_RS')) {
  print('Adding shard1...');
  sh.addShard('$S1_RS/$S1_HOST');
} else {
  print('Shard1 already added');
}
if (!shards.includes('$S2_RS')) {
  print('Adding shard2...');
  sh.addShard('$S2_RS/$S2_HOST');
} else {
  print('Shard2 already added');
}
"

# =========================
# 4) Enable sharding + shard collection
# =========================
log "Enable sharding for DB=$DB_NAME and shard collection $DB_NAME.$COLL_NAME"

exec_mongo mongos 27017 "
const dbName = '$DB_NAME';
const collName = '$COLL_NAME';
const ns = dbName + '.' + collName;

sh.enableSharding(dbName);

// Optionally drop collection first (useful if you previously inserted into unsharded collection)
if ('$DROP_COLLECTION' === 'true') {
  print('Dropping collection if exists: ' + ns);
  db.getSiblingDB(dbName).getCollection(collName).drop();
}

// Ensure index for shard key exists
if ('$SHARD_KEY_TYPE' === 'hashed') {
  db.getSiblingDB(dbName).getCollection(collName).createIndex({ _id: 'hashed' });
} else {
  db.getSiblingDB(dbName).getCollection(collName).createIndex({ _id: 1 });
}

// Check if already sharded
const cfg = db.getSiblingDB('config');
const coll = cfg.collections.findOne({ _id: ns });

if (coll && coll.dropped !== true) {
  print('Collection already sharded: ' + ns);
} else {
  print('Sharding collection: ' + ns);
  if ('$SHARD_KEY_TYPE' === 'hashed') {
    sh.shardCollection(ns, { _id: 'hashed' });
  } else {
    sh.shardCollection(ns, { _id: 1 });
  }
}
"

# =========================
# 5) Insert data + checks
# =========================
log "Insert $DOCS documents into $DB_NAME.$COLL_NAME and show checks"
exec_mongo mongos 27017 "
const dbName = '$DB_NAME';
const collName = '$COLL_NAME';
const n = Number('$DOCS');

const c = db.getSiblingDB(dbName).getCollection(collName);
for (let i = 0; i < 1000; i++) {
  c.insertOne({ age: i, name: \`ly\${i}\` });
}

print('Total documents via mongos: ' + c.countDocuments());
print('Shard distribution:');
printjson(c.getShardDistribution());
"

log "Direct counts on each shard (may be 0 if no chunks moved there yet)"
exec_mongo shard1 27018 "use $DB_NAME; print('shard1 count=' + db.getCollection('$COLL_NAME').countDocuments())"
exec_mongo shard2 27018 "use $DB_NAME; print('shard2 count=' + db.getCollection('$COLL_NAME').countDocuments())"

log "Done ✅"
