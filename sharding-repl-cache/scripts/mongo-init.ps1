# Инициализируем MongoDB шардирование с репликацией

# Инициализация сервера конфигурации
docker compose exec -T configSrv mongosh --port 27017 --quiet --eval "rs.initiate({_id:'config_server',configsvr:true,members:[{_id:0,host:'configSrv:27017'}]})"

Start-Sleep -Seconds 3

# Инициализация шарда 1 с репликацией (3 реплики)
docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval "rs.initiate({_id:'shard1',members:[{_id:0,host:'shard1-1:27018'},{_id:1,host:'shard1-2:27018'},{_id:2,host:'shard1-3:27018'}]})"

Start-Sleep -Seconds 3

# Инициализация шарда 2 с репликацией (3 реплики)
docker compose exec -T shard2-1 mongosh --port 27019 --quiet --eval "rs.initiate({_id:'shard2',members:[{_id:0,host:'shard2-1:27019'},{_id:1,host:'shard2-2:27019'},{_id:2,host:'shard2-3:27019'}]})"

Start-Sleep -Seconds 5

# Настройка роутера и добавление шардов
docker compose exec -T mongos_router1 mongosh --port 27020 --quiet --eval "sh.addShard('shard1/shard1-1:27018,shard1-2:27018,shard1-3:27018')"
docker compose exec -T mongos_router1 mongosh --port 27020 --quiet --eval "sh.addShard('shard2/shard2-1:27019,shard2-2:27019,shard2-3:27019')"
docker compose exec -T mongos_router1 mongosh --port 27020 --quiet --eval "sh.enableSharding('somedb')"
docker compose exec -T mongos_router1 mongosh --port 27020 --quiet --eval "sh.shardCollection('somedb.helloDoc',{name:'hashed'})"

# Добавление тестовых данных
docker compose exec -T mongos_router1 mongosh --port 27020 --quiet somedb --eval "db.helloDoc.deleteMany({}); for(var i=0;i<1000;i++) db.helloDoc.insert({age:i,name:'ly'+i}); db.helloDoc.countDocuments()"

# Проверка количества документов на шардах
docker compose exec -T shard1-1 mongosh --port 27018 --quiet somedb --eval "db.helloDoc.countDocuments()"
docker compose exec -T shard2-1 mongosh --port 27019 --quiet somedb --eval "db.helloDoc.countDocuments()"

