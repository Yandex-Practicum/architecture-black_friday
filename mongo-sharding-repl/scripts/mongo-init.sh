#!/bin/bash

docker compose exec -T configSrv mongosh --port 27017 <<EOF
rs.initiate(
  {
    _id : "config_server",
    configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" }
    ]
  }
);
exit();
EOF

docker compose exec -T shard1-rs01 mongosh --port 27022  <<EOF
rs.initiate(
    {
      _id : "shard1",
      members: [
        { _id : 0, host : "shard1-rs01:27022" },
        { _id : 1, host : "shard1-rs02:27023" },
        { _id : 2, host : "shard1-rs03:27024" }
      ]
    }
);
exit();
EOF

docker compose exec -T shard2-rs01 mongosh --port 27019 <<EOF

rs.initiate(
    {
      _id : "shard2",
      members: [
        { _id : 3, host : "shard2-rs01:27019" },
        { _id : 4, host : "shard2-rs02:27018" },
        { _id : 5, host : "shard2-rs03:27021" }
      ]
    }
  );
exit();
EOF

docker compose exec -T mongos_router mongosh --port 27020 <<EOF

sh.addShard( "shard1/shard1-rs01:27022");
sh.addShard( "shard1/shard1-rs02:27023");
sh.addShard( "shard1/shard1-rs03:27024");
sh.addShard( "shard2/shard2-rs01:27019");
sh.addShard( "shard2/shard2-rs02:27018");
sh.addShard( "shard2/shard2-rs03:27021");

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )

use somedb

for(var i = 0; i < 1000; i++) db.helloDoc.insert({age:i, name:"ly"+i})

exit();
EOF