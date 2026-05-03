# pymongo-api

## Как запустить

Запускаем mongodb и приложение

docker compose up -d


## Инициализация Config Server Replica Set 
docker compose exec -T configsrv mongosh --port 27019 --quiet --eval "rs.initiate({ _id: 'configReplSet', configsvr: true, members: [ { _id: 0, host: 'configsrv:27019' } ] })"

## Инициализация Replica Set shard1 (3 узла) 
docker compose exec -T shard1-primary mongosh --port 27018 --quiet --eval "rs.initiate({ _id: 'shard1ReplSet', members: [ { _id: 0, host: 'shard1-primary:27018' }, { _id: 1, host: 'shard1-secondary1:27018' }, { _id: 2, host: 'shard1-secondary2:27018' } ] })"

## Инициализация Replica Set shard2 (3 узла) 
docker compose exec -T shard2-primary mongosh --port 27018 --quiet --eval "rs.initiate({ _id: 'shard2ReplSet', members: [ { _id: 0, host: 'shard2-primary:27018' }, { _id: 1, host: 'shard2-secondary1:27018' }, { _id: 2, host: 'shard2-secondary2:27018' } ] })"

## Ожидание выбора primary (30 секунд) 
Start-Sleep -Seconds 30

## Добавление шардов в роутер 
docker compose exec -T mongos_router mongosh --port 27017 --quiet --eval "sh.addShard('shard1ReplSet/shard1-primary:27018,shard1-secondary1:27018,shard1-secondary2:27018')"
docker compose exec -T mongos_router mongosh --port 27017 --quiet --eval "sh.addShard('shard2ReplSet/shard2-primary:27018,shard2-secondary1:27018,shard2-secondary2:27018')"

## Включение шардирования БД somedb 
docker compose exec -T mongos_router mongosh --port 27017 --quiet --eval "sh.enableSharding('somedb')"

## Создание коллекции и настройка шардирования 
docker compose exec -T mongos_router mongosh --port 27017 --quiet --eval "db = db.getSiblingDB('somedb'); db.createCollection('helloDoc'); sh.shardCollection('somedb.helloDoc', { '_id': 'hashed' })"

## Наполнение данными (1000 документов) 
docker compose exec -T mongos_router mongosh --port 27017 --quiet --eval "db = db.getSiblingDB('somedb'); for (var i = 0; i < 1000; i++) { db.helloDoc.insertOne({ age: i, name: 'ly' + i }) }; print('Total documents:', db.helloDoc.countDocuments())"

## Распределение по шардам 
docker compose exec -T mongos_router mongosh --port 27017 --quiet --eval "db = db.getSiblingDB('somedb'); db.helloDoc.getShardDistribution()"

## Проверка количества реплик 

docker compose exec -T shard1-primary mongosh --port 27018 --quiet --eval "print(rs.status().members.length + ' members in shard1')"

docker compose exec -T shard2-primary mongosh --port 27018 --quiet --eval "print(rs.status().members.length + ' members in shard2')"
