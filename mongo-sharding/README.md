# pymongo-api

## Как запустить

Запускаем mongodb и приложение

docker compose up -d


# Инициализация конфигурационного сервера
docker compose exec -T configsrv mongosh --port 27019 --quiet --eval "rs.initiate({ _id: 'configReplSet', configsvr: true, members: [ { _id: 0, host: 'configsrv:27019' } ] })"

# Инициализация шарда 1
docker compose exec -T shard1 mongosh --port 27018 --quiet --eval "rs.initiate({ _id: 'shard1ReplSet', members: [ { _id: 0, host: 'shard1:27018' } ] })"

# Инициализация шарда 2
docker compose exec -T shard2 mongosh --port 27018 --quiet --eval "rs.initiate({ _id: 'shard2ReplSet', members: [ { _id: 0, host: 'shard2:27018' } ] })"

# Ожидание
Start-Sleep -Seconds 20

# Добавление шардов
docker compose exec -T mongos_router mongosh --port 27017 --quiet --eval "sh.addShard('shard1ReplSet/shard1:27018'); sh.addShard('shard2ReplSet/shard2:27018')"

# Включение шардирования БД
docker compose exec -T mongos_router mongosh --port 27017 --quiet --eval "sh.enableSharding('somedb')"

# Создание коллекции и шардирование
docker compose exec -T mongos_router mongosh --port 27017 --quiet --eval "db = db.getSiblingDB('somedb'); db.createCollection('helloDoc'); sh.shardCollection('somedb.helloDoc', { '_id': 'hashed' })"

# Вставка 1000 документов
docker compose exec -T mongos_router mongosh --port 27017 --quiet --eval "db = db.getSiblingDB('somedb'); for(var i = 0; i < 1000; i++) { db.helloDoc.insertOne({ age: i, name: 'ly' + i }) }; print('Count:', db.helloDoc.countDocuments())"

# Проверка распределения
docker compose exec -T mongos_router mongosh --port 27017 --quiet --eval "db = db.getSiblingDB('somedb'); db.helloDoc.getShardDistribution()"