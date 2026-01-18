#!/bin/bash

###
# Инициализируем бд
###

echo "init configSrv"
docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate(
  {
    _id : "config_server",
       configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" }
    ]
  }
);
EOF

echo "init shard1"
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.initiate(
    {
      _id : "shard1",
      members: [
        { _id : 0, host : "shard1-1:27018" },
        { _id : 1, host : "shard1-2:27019" },
        { _id : 2, host : "shard1-3:27020" }
      ]
    }
);
EOF

echo "init shard2"
docker compose exec -T shard2-1 mongosh --port 27021 --quiet <<EOF
rs.initiate(
    {
      _id : "shard2",
      members: [
        { _id : 0, host : "shard2-1:27021" },
        { _id : 1, host : "shard2-2:27022" },
        { _id : 2, host : "shard2-3:27023" }
      ]
    }
  );
exit();
EOF

echo "Waiting for shards to be ready..."
sleep 5

echo "exec mongos_router ..."
docker compose exec -T mongos_router mongosh --port 27016 --quiet <<EOF
sh.addShard("shard1/shard1-1:27018,shard1-2:27019,shard1-3:27020");
sh.addShard("shard2/shard2-1:27021,shard2-2:27022,shard2-3:27023");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } );
use somedb;
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i});
db.helloDoc.countDocuments();
EOF







