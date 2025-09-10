Задание 2. Шардирование

1. Поднимаем конфигурацию в файле compose.yaml
    ```
   docker compose up -d
    ```
2. Выполняем команду
    ```
    docker exec -it configSrv mongosh --port 27017 --eval 'rs.initiate({ _id: \"config_server\", configsvr: true, members: [{ _id: 0, host: \"configSrv:27017\" }] })'
    ```
3. Выполняем команду
    ```
    docker exec -it shard1 mongosh --port 27011 --eval 'rs.initiate({ _id: \"shard1\", members: [{ _id: 0, host: \"shard1:27011\" }] });'
    ```
4. Выполняем команду
    ```
    docker exec -it shard2 mongosh --port 27012 --eval 'rs.initiate({ _id: \"shard2\", members: [{ _id: 1, host: \"shard2:27012\" }] });'
    ```
5. Выполняем команду
    ```
    docker exec -it mongos_router mongosh --port 27017 --eval '
    sh.addShard(\"shard1/shard1:27011\");
    sh.addShard(\"shard2/shard2:27012\");
    sh.enableSharding(\"somedb\");
    sh.shardCollection(\"somedb.helloDoc\", { "name" : \"hashed\" });
    db = db.getSiblingDB(\"somedb\");
    for (var i = 0; i < 1000; i++) { db.helloDoc.insert({ age: i, name: \"ly\" + i }); }'
    ```
6. Для проверки открываем [API](http://localhost:8080 "Root"), где в результате должны видеть 2 шарда ()"shard1": "shard1/shard1:27011","shard2": "shard2/shard2:27012"), а также коллекцию helloDoc, которая содержит 1000 документов
7. Для проверки количество документов на шарде shard1 следует выполнить команду:
    ```
    docker exec -it shard1 mongosh --port 27011 --eval '
    db = db.getSiblingDB(\"somedb\");
    print(\"Shard1 documents in helloDoc: \" + db.helloDoc.countDocuments())'
    ```
 В виде результата получим 
```
Shard1 documents in helloDoc: 492
```
