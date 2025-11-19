#!/bin/bash

set -e

echo "Starting mongos router..."
mongos --configdb config_server/mongo_config_srv:27017 --bind_ip_all --port 27020 &

echo "Waiting for mongos to start..."
until mongosh --port 27020 --eval "db.adminCommand('ping')" --quiet > /dev/null 2>&1; do
  sleep 1
done

echo "Adding shards to cluster..."
mongosh --port 27020 <<EOF
sh.addShard('shard1/mongo_shard1:27018')
sh.addShard('shard2/mongo_shard2:27019')
sh.enableSharding('somedb')
sh.shardCollection('somedb.helloDoc', {name: 'hashed'})
EOF

echo "Inserting data into collection..."
mongosh --port 27020 somedb <<EOF
for(var i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({age:i, name:'ly'+i})
}
EOF

echo "Mongos router initialized"
wait
