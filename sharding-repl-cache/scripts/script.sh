#!/bin/bash

echo "Инициализация сервера конфигурации"
docker exec -it configSrv mongosh --port 27017 --quiet --eval '
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv:27017" }
  ]
});
'

echo "Инициализация shard1"
docker exec -it shard1-1 mongosh --port 27018 --quiet --eval '
rs.initiate({
  _id : "shard1",
  members: [
    { _id : 0, host : "shard1-1:27018" },
    { _id : 1, host : "shard1-2:27018" },
    { _id : 2, host : "shard1-3:27018" }
  ]
});
'

echo "Инициализация shard2"
docker exec -it shard2-1 mongosh --port 27019 --quiet --eval '
rs.initiate({
  _id : "shard2",
  members: [
    { _id : 0, host : "shard2-1:27019" },
    { _id : 1, host : "shard2-2:27019" },
    { _id : 2, host : "shard2-3:27019" }
  ]
});
'

echo "Инициализация роутера и включение шардинга"
docker exec -it  mongos_router mongosh --port 27020 --quiet --eval '
sh.addShard("shard1/shard1-1:27018");
sh.addShard("shard2/shard2-1:27019");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } );
'

echo "Добавление тестовых данных"
docker exec -it  mongos_router mongosh --port 27020 --quiet --eval '
use("somedb");
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i});
print("Общее количество документов:" + db.helloDoc.countDocuments());
'

echo "shard1:"
docker exec shard1-1 mongosh --port 27018 --quiet --eval '
use("somedb");
print("Количество документов:" + db.helloDoc.countDocuments());
var status = rs.status();
var members = status.members;
print("Количество реплик: " + members.length);
'

echo "shard2:"
docker exec shard2-1 mongosh --port 27019 --quiet --eval '
use("somedb");
print("Количество документов:" + db.helloDoc.countDocuments());
var status = rs.status();
var members = status.members;
print("Количество реплик: " + members.length);
'