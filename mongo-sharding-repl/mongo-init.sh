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
docker compose exec -T shard1_r1 mongosh --port 27011 --quiet <<EOF
rs.initiate(
  {
    _id : "shard1",
    members: [
      { _id : 0, host : "shard1_r1:27011" },
      { _id : 1, host : "shard1_r2:27012" },
      { _id : 2, host : "shard1_r3:27013" },
      { _id : 3, host : "shard1_r4:27014" }
    ]
  }
);
EOF

# Инициализация shard2
docker compose exec -T shard2_r1 mongosh --port 27021 --quiet <<EOF
rs.initiate(
  {
    _id : "shard2",
    members: [
      { _id : 0, host : "shard2_r1:27021" },
      { _id : 1, host : "shard2_r2:27022" },
      { _id : 2, host : "shard2_r3:27023" },
      { _id : 3, host : "shard2_r4:27024" }
    ]
  }
);
EOF

echo sleep for 5 seconds...
sleep 5

echo init mongos_router
# Инициализация router и заливка данных
docker compose exec -T mongos_router mongosh --port 27017 --quiet <<EOF
sh.addShard( "shard1/shard1_r1:27011");
sh.addShard( "shard2/shard2_r1:27021");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
print("Общее количество документов: " + db.helloDoc.countDocuments())
EOF

# выводим количество документов в shard1
docker compose exec -T shard1_r1 mongosh --port 27011 --quiet <<EOF
use somedb;
print("Количество документов в shard1: " + db.helloDoc.countDocuments())
print("Количество реплик в shard1: " + rs.conf().members.length)
EOF

# выводим количество документов в shard2
docker compose exec -T shard2_r1 mongosh --port 27021 --quiet <<EOF
use somedb;
print("Количество документов в shard2: " + db.helloDoc.countDocuments())
print("Количество реплик в shard2: " + rs.conf().members.length)
EOF