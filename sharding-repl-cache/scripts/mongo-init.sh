#!/bin/bash

###
# Инициализация configSrv
###
docker compose exec -T configSrv1 mongosh --port 27017 <<EOF
rs.initiate(
  {
    _id : "config_server",
    configsvr: true,
    members: [
      { _id : 0, host : "configSrv1:27017" },
      { _id : 1, host : "configSrv2:27017" },
      { _id : 2, host : "configSrv3:27017" }
    ]
  }
);
EOF

sleep 10

###
# Инициализация shard1
###
docker compose exec -T shard1-1 mongosh --port 27018 <<EOF
rs.initiate(
  {
    _id : "shard1",
    members: [
      { _id : 0, host : "shard1-1:27018" },
      { _id : 1, host : "shard1-2:27018" },
      { _id : 2, host : "shard1-3:27018" }
    ]
  }
);
EOF

sleep 10

###
# Инициализация shard2
###

docker compose exec -T shard2-1 mongosh --port 27019 <<EOF
rs.initiate(
  {
    _id : "shard2",
    members: [
      { _id : 0, host : "shard2-1:27019" },
      { _id : 1, host : "shard2-2:27019" },
      { _id : 2, host : "shard2-3:27019" }
    ]
  }
);
EOF


sleep 10

###
# Инициализация mongos_router и наполнение тестовыми данными
###
docker compose exec -T mongos_router mongosh --port 27020 <<EOF
sh.addShard("shard1/shard1-1:27018,shard1-2:27018,shard1-3:27018");
sh.addShard("shard2/shard2-1:27019,shard2-2:27019,shard2-3:27019");

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )

use somedb

for(var i = 0; i < 1000; i++) db.helloDoc.insert({age:i, name:"ly"+i})

db.helloDoc.countDocuments()
EOF

sleep 10

count_docs() {
  server=$1
  port=$2

  echo "$server..."
  docker compose exec -T $server mongosh --port $port <<EOF
  use somedb;
  db.helloDoc.countDocuments();
EOF
}

###
# Проверка shard1
###
echo "--- Checking replicaset shard1"
docker compose exec -T shard1-1 mongosh --port 27018 --eval "rs.status()" | grep "name\|stateStr"

count_docs shard1-1 27018
count_docs shard1-2 27018
count_docs shard1-3 27018

###
# Проверка shard2
###

echo "--- Checking replicaset shard2"
docker compose exec -T shard2-1 mongosh --port 27019 --eval "rs.status()" | grep "name\|stateStr"
count_docs shard2-1 27019
count_docs shard2-2 27019
count_docs shard2-3 27019

