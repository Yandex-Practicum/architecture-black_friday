# Задание 2. Шардирование

1. Поднимаем compose.yaml
2. Запускаем
    ```
    docker exec -it configSrv mongosh --port 27017 --eval 'rs.initiate({ _id: \"config_server\", configsvr: true, members: [{ _id: 0, host: \"configSrv:27017\" }] })'
    ```
3. Запускаем
    ```
    docker exec -it shard1 mongosh --port 27011 --eval 'rs.initiate({ _id: \"shard1\", members: [{ _id: 0, host: \"shard1:27011\" }] });'
    ```
4. Запускаем
    ```
    docker exec -it shard2 mongosh --port 27012 --eval 'rs.initiate({ _id: \"shard2\", members: [{ _id: 1, host: \"shard2:27012\" }] });'
    ```
5. Запускаем
    ```
    docker exec -it mongos_router mongosh --port 27017 --eval '
    sh.addShard(\"shard1/shard1:27011\");
    sh.addShard(\"shard2/shard2:27012\");
    sh.enableSharding(\"somedb\");
    sh.shardCollection(\"somedb.helloDoc\", { "name" : \"hashed\" });
    db = db.getSiblingDB(\"somedb\");
    for (var i = 0; i < 1000; i++) { db.helloDoc.insert({ age: i, name: \"ly\" + i }); }'
    ```
6. Открываем [API](http://localhost:8080 "Root"), видим 2 шарда, коллекцию helloDoc с 1000 документов
7. Проверяем количество документов на шардах, например на shard1: 
    ```
    docker exec -it shard1 mongosh --port 27011 --eval '
    db = db.getSiblingDB(\"somedb\");
    print(\"Shard1 documents in helloDoc: \" + db.helloDoc.countDocuments())'
    ```
результат
```
Shard1 documents in helloDoc: 492
```
8. Второй шард можно проверить аналогично