# Задание 2. Шардирование

1. Поднимаем compose.yaml
2. rs.initiate(
    {
      _id : "shard1",
      members: [
        { _id : 0, host : "shard1:27011" }
      ]
    }
);
3. rs.initiate(
    {
      _id : "shard2",
      members: [
        { _id : 1, host : "shard2:27012" }
      ]
    }
);
4. Запускаем mongo-sharding\scripts\configsvr\init.sh
5. Запускаем mongo-sharding\scripts\router\init.sh
6. Открываем [API](http://localhost:8080 "Root"), видим 2 шарда, коллекцию helloDoc с 1000 документов
7. Проверяем количество документов на шардах, например на shard1: 
   1. docker exec -it shard1 mongosh --port 27012
   2. use somedb
   3. db.helloDoc.countDocuments() ~ 492 документа
8. Второй шард можно проверить аналогично