#!/bin/bash

set -e

echo "Starting shard1..."
mongod --shardsvr --replSet shard1 --bind_ip_all --port 27018 --dbpath /data/db &

echo "Waiting for MongoDB to be ready..."
until mongosh --port 27018 --eval "db.adminCommand('ping')" --quiet > /dev/null 2>&1; do
  sleep 1
done

echo "Initializing shard1 replica set..."
mongosh --port 27018 <<EOF
rs.initiate({
  _id: 'shard1',
  members: [
    {_id: 0, host: 'mongo_shard1_node1:27018'},
    {_id: 1, host: 'mongo_shard1_node2:27018'},
    {_id: 2, host: 'mongo_shard1_node3:27018'}
  ]
})
EOF

echo "Shard1 initialized"
wait
