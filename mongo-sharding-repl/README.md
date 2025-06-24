# Задание 3. Репликация

1. Поднимаем compose.yaml
2. Запускаем
   ```
   docker exec -it configSrv mongosh --port 27017 --eval 'rs.initiate({ _id: \"config_server\", configsvr: true, members: [{ _id: 0, host: \"configSrv:27017\" }] })'
   ```
3. Настраиваем шарды с репликами
   первый шард
   ```
   docker exec -it shard1 mongosh --port 27011 --eval '
   rs.initiate({
      _id: \"shard1\",
      members: [
         { _id: 0, host: \"shard1:27011\" },
         { _id: 1, host: \"shard1-r1:27013\" },
         { _id: 2, host: \"shard1-r2:27014\" },
         { _id: 3, host: \"shard1-r3:27015\" }
      ]
   })'
   ```
   второй шард
   ```
   docker exec -it shard2 mongosh --port 27012 --eval '
   rs.initiate({
      _id: \"shard2\",
      members: [
         { _id: 0, host: \"shard2:27012\" },
         { _id: 1, host: \"shard2-r1:27016\" },
         { _id: 2, host: \"shard2-r2:27018\" },
         { _id: 3, host: \"shard2-r3:27019\" }
      ]
   })'
   ```
5. Запускаем 
   ```
   docker exec -it mongos_router mongosh --port 27017 --eval '
   sh.addShard(\"shard1/shard1:27011,shard1-r1:27013,shard1-r2:27014,shard1-r3:27015\");
   sh.addShard(\"shard2/shard2:27012,shard2-r1:27016,shard2-r2:27018,shard2-r3:27019\");
   sh.enableSharding(\"somedb\");
   sh.shardCollection(\"somedb.helloDoc\", { "name" : \"hashed\" });
   db = db.getSiblingDB(\"somedb\");
   for (var i = 0; i < 1000; i++) { db.helloDoc.insert({ age: i, name: \"ly\" + i }); }'
   ```
6. Дальше как в 6,7,8 из mongo-sharding\README.md