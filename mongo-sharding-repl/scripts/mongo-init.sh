#!/usr/bin/bash

docker compose exec -T configSrv mongosh --port 27017 <<EOF
rs.initiate({
  _id : "config_server",
     configsvr: true,
  members: [
    { _id : 0, host : "configSrv:27017" }
  ]
});
EOF

docker compose exec -T shard1repl1 mongosh --port 27030 <<EOF
rs.initiate({_id: "shard1", members: [
  {_id: 0, host: "shard1repl1:27030"},
  {_id: 1, host: "shard1repl2:27031"},
  {_id: 2, host: "shard1repl3:27032"}
]})
EOF

docker compose exec -T shard2repl1 mongosh --port 27040 <<EOF
rs.initiate({_id: "shard2", members: [
  {_id: 0, host: "shard2repl1:27040"},
  {_id: 1, host: "shard2repl2:27041"},
  {_id: 2, host: "shard2repl3:27042"}
]})
EOF

docker compose exec -T mongos_router mongosh --port 27020 <<EOF
sh.addShard("shard1/shard1repl1:27030");
sh.addShard("shard2/shard2repl1:27040");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insert({age:i, name:"ly"+i})
db.helloDoc.countDocuments()
EOF

docker compose exec -T shard1repl1 mongosh --port 27030 <<EOF
use somedb;
db.helloDoc.countDocuments();
EOF

docker compose exec -T shard2repl1 mongosh --port 27040 <<EOF
use somedb;
db.helloDoc.countDocuments();
EOF

