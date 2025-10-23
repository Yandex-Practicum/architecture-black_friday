#!/bin/bash

docker compose exec -T configSrv mongosh --port 27017 <<EOF
rs.initiate(
    {
        _id: "config_servers",
        configsvr: true,
        members: [
            { _id: 0, host: "configSrv:27017" }
        ]
    }
);
EOF

docker compose exec -T shard1-1 mongosh --port 27018 <<EOF
rs.initiate(
    {
        _id: "shard1",
        members: [
            { _id: 0, host: "shard1-1:27018" },
            { _id: 1, host: "shard1-2:27019" },
            { _id: 2, host: "shard1-3:27020" }
        ]
    }
);
EOF

docker compose exec -T shard2-1 mongosh --port 27021 <<EOF
rs.initiate(
    {
        _id: "shard2",
        members: [
            { _id: 0, host: "shard2-1:27021" },
            { _id: 1, host: "shard2-2:27022" },
            { _id: 2, host: "shard2-3:27023" }
        ]
    }
);
EOF

sleep 5

docker compose exec -T mongos_router mongosh --port 27024 <<EOF
sh.addShard("shard1/shard1-1:27018,shard1-2:27019,shard1-3:27020");
sh.addShard("shard2/shard2-1:27021,shard2-2:27022,shard2-3:27023");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } );
use somedb;
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i});
EOF
