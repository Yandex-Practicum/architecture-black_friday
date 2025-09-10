Задание 2. Шардирование

1. Поднимаем конфигурацию в файле compose.yaml
    ```
   docker compose up -d
    ```
2. Выполняем команду
    ```
    docker exec -it configSrv mongosh --port 27017 --eval 'rs.initiate({ _id: \"config_server\", configsvr: true, members: [{ _id: 0, host: \"configSrv:27017\" }] })'
    ```
3. Выполняем команду для настройки шардов с репликациями для shard 1 и shard 2:
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

4. Выполняем команду
    ```
    docker exec -it mongos_router mongosh --port 27017 --eval '
    sh.addShard(\"shard1/shard1:27011,shard1-r1:27013,shard1-r2:27014,shard1-r3:27015\");
    sh.addShard(\"shard2/shard2:27012,shard2-r1:27016,shard2-r2:27018,shard2-r3:27019\");
    sh.enableSharding(\"somedb\");
    sh.shardCollection(\"somedb.helloDoc\", { "name" : \"hashed\" });
    db = db.getSiblingDB(\"somedb\");
    for (var i = 0; i < 1000; i++) { db.helloDoc.insert({ age: i, name: \"ly\" + i }); }'
    ```
5. Для проверки открываем [API](http://localhost:8080 "Root"), где в результате должны видеть 2 шарда c тремя репликами каждого ("shard1": "shard1/shard1:27011,shard1-r1:27013,shard1-r2:27014,shard1-r3:27015","shard2": "shard2/shard2:27012,shard2-r1:27016,shard2-r2:27018,shard2-r3:27019"), а также коллекцию helloDoc, которая содержит 1000 документов
6. Для проверки количество документов на шарде shard1 следует выполнить команду:
    ```
    docker exec -it shard1 mongosh --port 27011 --eval '
    db = db.getSiblingDB(\"somedb\");
    print(\"Shard1 documents in helloDoc: \" + db.helloDoc.countDocuments())'
    ```
 В виде результата получим 
```
Shard1 documents in helloDoc: 492
```
