#!/usr/bin/env bash
set -euo pipefail

# =========================
# Config (можно менять)
# =========================
DB_NAME="${DB_NAME:-somedb}"
COLL_NAME="${COLL_NAME:-helloDoc}"
DOCS="${DOCS:-2000}"
SHARD_KEY_TYPE="${SHARD_KEY_TYPE:-hashed}"   # hashed или 1
DROP_COLLECTION="${DROP_COLLECTION:-true}"   # true/false

# =========================
# Replica set names
# =========================
CFG_RS="configReplSet"
S1_RS="shard1ReplSet"
S2_RS="shard2ReplSet"

# =========================
# Services/ports (должны совпасть с docker compose)
# =========================
CFG_PORT=27019
S1_PORT=27018
S2_PORT=27018
MONGOS_PORT=27017

CFG_SVCS=(configsvr1 configsvr2 configsvr3)
S1_SVCS=(shard1-1 shard1-2 shard1-3)
S2_SVCS=(shard2-1 shard2-2 shard2-3)

# host strings for rs + addShard
CFG_HOSTS="configsvr1:${CFG_PORT},configsvr2:${CFG_PORT},configsvr3:${CFG_PORT}"
S1_HOSTS="shard1-1:${S1_PORT},shard1-2:${S1_PORT},shard1-3:${S1_PORT}"
S2_HOSTS="shard2-1:${S2_PORT},shard2-2:${S2_PORT},shard2-3:${S2_PORT}"

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
  for i in {1..90}; do
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
for s in "${CFG_SVCS[@]}"; do wait_mongo "$s" "$CFG_PORT"; done
for s in "${S1_SVCS[@]}"; do wait_mongo "$s" "$S1_PORT"; done
for s in "${S2_SVCS[@]}"; do wait_mongo "$s" "$S2_PORT"; done

# =========================
# 1) Initiate Config RS (3 nodes)
# =========================
log "Init Config RS ($CFG_RS) if needed"
exec_mongo "${CFG_SVCS[0]}" "$CFG_PORT" "
try {
  const st = rs.status();
  if (st.ok === 1) { print('Config RS already initiated'); }
  else { throw new Error('status not ok'); }
} catch (e) {
  print('Initiating Config RS...');
  rs.initiate({
    _id: '$CFG_RS',
    configsvr: true,
    members: [
      { _id: 0, host: '${CFG_SVCS[0]}:$CFG_PORT' },
      { _id: 1, host: '${CFG_SVCS[1]}:$CFG_PORT' },
      { _id: 2, host: '${CFG_SVCS[2]}:$CFG_PORT' }
    ]
  });
}
"

# Wait mongos now that config RS exists
wait_mongo mongos "$MONGOS_PORT"

# =========================
# 2) Initiate shard replica sets (3 nodes each)
# =========================
log "Init Shard1 RS ($S1_RS) if needed"
exec_mongo "${S1_SVCS[0]}" "$S1_PORT" "
try {
  const st = rs.status();
  if (st.ok === 1) { print('Shard1 RS already initiated'); }
  else { throw new Error('status not ok'); }
} catch (e) {
  print('Initiating Shard1 RS...');
  rs.initiate({
    _id: '$S1_RS',
    members: [
      { _id: 0, host: '${S1_SVCS[0]}:$S1_PORT' },
      { _id: 1, host: '${S1_SVCS[1]}:$S1_PORT' },
      { _id: 2, host: '${S1_SVCS[2]}:$S1_PORT' }
    ]
  });
}
"

log "Init Shard2 RS ($S2_RS) if needed"
exec_mongo "${S2_SVCS[0]}" "$S2_PORT" "
try {
  const st = rs.status();
  if (st.ok === 1) { print('Shard2 RS already initiated'); }
  else { throw new Error('status not ok'); }
} catch (e) {
  print('Initiating Shard2 RS...');
  rs.initiate({
    _id: '$S2_RS',
    members: [
      { _id: 0, host: '${S2_SVCS[0]}:$S2_PORT' },
      { _id: 1, host: '${S2_SVCS[1]}:$S2_PORT' },
      { _id: 2, host: '${S2_SVCS[2]}:$S2_PORT' }
    ]
  });
}
"

# =========================
# 3) Add shards to cluster (mongos) - idempotent
# =========================
log "Add shards to cluster (idempotent)"
exec_mongo mongos "$MONGOS_PORT" "
const shards = db.getSiblingDB('config').shards.find().toArray().map(s => s._id);

if (!shards.includes('$S1_RS')) {
  print('Adding shard1...');
  sh.addShard('$S1_RS/$S1_HOSTS');
} else {
  print('Shard1 already added');
}

if (!shards.includes('$S2_RS')) {
  print('Adding shard2...');
  sh.addShard('$S2_RS/$S2_HOSTS');
} else {
  print('Shard2 already added');
}
"

# =========================
# 4) Enable sharding + shard collection
# =========================
log "Enable sharding for DB=$DB_NAME and shard collection $DB_NAME.$COLL_NAME"
exec_mongo mongos "$MONGOS_PORT" "
const dbName = '$DB_NAME';
const collName = '$COLL_NAME';
const ns = dbName + '.' + collName;

sh.enableSharding(dbName);

if ('$DROP_COLLECTION' === 'true') {
  print('Dropping collection if exists: ' + ns);
  db.getSiblingDB(dbName).getCollection(collName).drop();
}

if ('$SHARD_KEY_TYPE' === 'hashed') {
  db.getSiblingDB(dbName).getCollection(collName).createIndex({ _id: 'hashed' });
} else {
  db.getSiblingDB(dbName).getCollection(collName).createIndex({ _id: 1 });
}

const cfg = db.getSiblingDB('config');
const coll = cfg.collections.findOne({ _id: ns });

if (coll && coll.dropped !== true) {
  print('Collection already sharded: ' + ns);
} else {
  print('Sharding collection: ' + ns);
  if ('$SHARD_KEY_TYPE' === 'hashed') sh.shardCollection(ns, { _id: 'hashed' });
  else sh.shardCollection(ns, { _id: 1 });
}
"

# =========================
# 5) Insert data + checks
# =========================
log "Insert docs into $DB_NAME.$COLL_NAME and show checks"
exec_mongo mongos "$MONGOS_PORT" "
const dbName = '$DB_NAME';
const collName = '$COLL_NAME';
const n = Number('$DOCS');

const c = db.getSiblingDB(dbName).getCollection(collName);

for (let i = 0; i < n; i++) {
  c.insertOne({ age: i, name: \`ly\${i}\`, createdAt: new Date() });
}

print('Total documents via mongos: ' + c.countDocuments());
print('Shard distribution:');
printjson(c.getShardDistribution());
"

# =========================
# 6) Show RS member counts (for сдачу)
# =========================
log "Replica set member counts (for report)"
exec_mongo "${CFG_SVCS[0]}" "$CFG_PORT" "print('config members=' + rs.status().members.length)"
exec_mongo "${S1_SVCS[0]}" "$S1_PORT" "print('shard1 members=' + rs.status().members.length)"
exec_mongo "${S2_SVCS[0]}" "$S2_PORT" "print('shard2 members=' + rs.status().members.length)"

log "Done ✅"
