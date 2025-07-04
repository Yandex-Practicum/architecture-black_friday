#!/bin/bash

# Инициализация config-server
docker compose exec -T config_server mongosh --port 27003 --quiet <<EOF
rs.initiate(
  {
    _id : "config_server",
       configsvr: true,
    members: [
      { _id : 0, host : "config_server:27003" }
    ]
  }
);
EOF

# Инициализация shard1
docker compose exec -T shard1 mongosh --port 27004 --quiet <<EOF
rs.initiate(
  {
    _id : "shard1",
    members: [
      { _id : 0, host : "shard1:27004" },
    ]
  }
);
EOF

# Инициализация shard2
docker compose exec -T shard2 mongosh --port 27005 --quiet <<EOF
rs.initiate(
  {
    _id : "shard2",
    members: [
      { _id : 0, host : "shard2:27005" },
    ]
  }
);
EOF

echo sleep for 5 seconds...
sleep 5

echo init mongos-router
# Инициализация mongos-router и заливка данных
docker compose exec -T mongos_router mongosh --port 27017 --quiet <<EOF
sh.addShard( "shard1/shard1:27004");
sh.addShard( "shard2/shard2:27005");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
print("Общее количество документов: " + db.helloDoc.countDocuments())
EOF

# выводим количество документов в mongo-shard1
docker compose exec -T shard1 mongosh --port 27004 --quiet <<EOF
use somedb;
print("Количество документов в shard1: " + db.helloDoc.countDocuments())
EOF

# выводим количество документов в mongo-shard2
docker compose exec -T shard2 mongosh --port 27005 --quiet <<EOF
use somedb;
print("Количество документов в shard2: " + db.helloDoc.countDocuments())
EOF