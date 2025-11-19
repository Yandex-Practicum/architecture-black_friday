#!/bin/bash

set -e

echo "Starting config server..."
mongod --configsvr --replSet config_server --bind_ip_all --port 27017 --dbpath /data/db &

echo "Waiting for MongoDB to be ready..."
until mongosh --port 27017 --eval "db.adminCommand('ping')" --quiet > /dev/null 2>&1; do
  sleep 1
done

echo "Initializing config server replica set..."
mongosh --port 27017 <<EOF
rs.initiate({
  _id: 'config_server',
  configsvr: true,
  members: [
    {_id: 0, host: 'mongo_config_srv:27017'}
  ]
})
EOF

echo "Config server initialized"
wait
