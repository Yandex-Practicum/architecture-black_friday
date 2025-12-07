# pymongo-api

## Как запустить

Запускаем mongodb и приложение; ждём запуска и конфигурируем; заполняем данными

```powershell
.\scripts\mongo-init.ps1 -Reset
```

Заполняем mongodb данными

## Как убедиться, что репликация работает:

1) Посмотреть вывод http://localhost:8080/
```
  ...
  "shards": {
    "shard1": "shard1/mongo_shard1_1:27018,mongo_shard1_2:27018,mongo_shard1_3:27018",
    "shard2": "shard2/mongo_shard2_1:27019,mongo_shard2_2:27019,mongo_shard2_3:27019"
  },
  ...
```

2) Подключиться к двум нодам и проверить, что обе содержат юзера из helloDoc
    - подключиться к primary инстансу
    `docker compose exec mongo_shard1_1 mongosh --port 27018`
    - найти по имени какого-то юзера, который находтся в этом шарде
    ```
    db.getSiblingDB('somedb').helloDoc.find({name: 'ly1'})
    [ { _id: ObjectId('6934891687af04c8899dc29e'), age: 1, name: 'ly1' } ]
    ```
    - подключиться к secondary ноде в том же шарде
    `docker compose exec mongo_shard1_2 mongosh --port 27018`
    - найти того же юзера по id (или тоже по имени)
    ```
    shard1 [direct: secondary] test> db.getSiblingDB('somedb').helloDoc.find({_id: ObjectId('6934891687af04c8899dc29e')})
    [ { _id: ObjectId('6934891687af04c8899dc29e'), age: 1, name: 'ly1' } ]
    ```