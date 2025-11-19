#!/bin/bash

set -e

echo "Starting shard2..."
mongod --shardsvr --replSet shard2 --bind_ip_all --port 27019 --dbpath /data/db &

echo "Waiting for MongoDB to be ready..."
until mongosh --port 27019 --eval "db.adminCommand('ping')" --quiet > /dev/null 2>&1; do
  sleep 1
done

echo "Initializing shard2 replica set..."
mongosh --port 27019 <<EOF
rs.initiate({
  _id: 'shard2',
  members: [
    {_id: 0, host: 'mongo_shard2_node1:27019'},
    {_id: 1, host: 'mongo_shard2_node2:27019'},
    {_id: 2, host: 'mongo_shard2_node3:27019'}
  ]
})
EOF

echo "Shard2 initialized"
wait
