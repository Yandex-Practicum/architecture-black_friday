Задание 2. Шардирование

1. Поднимаем compose.yaml
2. Запускаем mongo-sharding\scripts\configsvr\init.sh
3. Запускаем mongo-sharding\scripts\router\init.sh
4. Открываем [API](http://localhost:8080 "Root"), видим 2 шарда, коллекцию helloDoc с 1000 документов
5. Проверяем количество документов на шардах, например на shard1: 
   1. docker exec -it shard1 mongosh --port 27012
   2. use somedb
   3. db.helloDoc.countDocuments() ~ 492 документа
6. Второй шард можно проверить аналогично