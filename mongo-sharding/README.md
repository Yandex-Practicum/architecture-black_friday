# pymongo-api

## Как запустить

Запускаем mongodb и приложение

```shell
docker compose up -d
```

Заполняем mongodb данными и инициализируем роутер и конфиг

```shell
./scripts/mongo-init.sh
```

## Как проверить через pymongo-api:

Откройте в браузере http://localhost:8080 - данные о MongoDB  
![Отображение шардов в pymongo](screens/app_with_shard.png)  

Откройте в браузере http://localhost:8080/helloDoc/count - количество записей в базе  

## Проверка внутри контейнеров средствами mongosh:
```shell
docker compose exec -T shard1 mongosh --port 27018 --quiet  
shard1 [direct: primary] somed> use somedb  
switched to db somedb  
shard1 [direct: primary] somedb> db.helloDoc.countDocuments()  
492  
  
docker compose exec -T shard2 mongosh --port 27019 --quiet  
shard2 [direct: primary] test> use somedb  
switched to db somedb  
shard2 [direct: primary] somedb> db.helloDoc.countDocuments()  
508  
```  

![Отображение распределения по шардам](screens/check_mongo.png)  
```shell
docker exec -it mongos_router mongosh somedb --eval "db.helloDoc.getShardDistribution()"  
```  
![Отображение распределения по шардам](screens/check_mongo2.png)  

![Ининциализация mongoDB](screens/init_mongo.png)  

