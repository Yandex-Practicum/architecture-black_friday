1. Инициализация сервера конфигурации
```console
docker exec -it configSrv mongosh --port 27017 --quiet --eval '
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv:27017" }
  ]
});
'
```

2. Инициализация шардов
```console
docker exec -it shard1 mongosh --port 27018 --quiet --eval '
rs.initiate({
  _id : "shard1",
  members: [
    { _id : 0, host : "shard1:27018" },
  ]
});
'
```

```console
docker exec -it shard2 mongosh --port 27019 --quiet --eval '
rs.initiate({
  _id : "shard2",
  members: [
    { _id : 0, host : "shard2:27019" },
  ]
});
'
```

3. Инициализация роутера и включение шардинга
```console 
docker exec -it  mongos_router mongosh --port 27020 --quiet --eval '
sh.addShard("shard1/shard1:27018");
sh.addShard("shard2/shard2:27019");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } );
'
```    

4. Добавление тестовых данных
```console 
docker exec -it  mongos_router mongosh --port 27020 --quiet --eval '
use("somedb");
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i});
db.helloDoc.countDocuments() ;
'
``` 
5. Вывод количества документов на shard1
```console
docker exec -it shard1 mongosh --port 27018 --quiet --eval '
use("somedb");
db.helloDoc.countDocuments();
'
```
6. Вывод количества документов на shard2
```console
docker exec -it shard2 mongosh --port 27019 --quiet --eval '
use("somedb");
db.helloDoc.countDocuments();
'
```
7. Вывод общего количества документов
```console
docker exec -it mongos_router mongosh --port 27020 --quiet --eval '
use("somedb");
db.helloDoc.countDocuments();
'
```