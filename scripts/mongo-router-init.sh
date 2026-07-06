#!/bin/bash

docker compose up mongos-router -d --build

until [ "$(docker inspect -f '{{.State.Health.Status}}' mongos-router)" == "healthy" ]; do sleep 1; done

docker compose exec -T mongos-router mongosh --port 27017 --quiet <<EOF
db.adminCommand("flushRouterConfig");

sh.addShard("shard1/shard1-1:27020");
sh.addShard("shard2/shard2-1:27030");

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" })

use somedb

for(var i = 0; i < 1000; i++) db.helloDoc.insert({age:i, name:"ly"+i})

db.helloDoc.countDocuments() 
exit();
EOF