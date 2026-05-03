# pymongo-api

docker pull kazhem/pymongo_api:1.0.0

## Как запустить
## Запускаем mongodb и приложение
docker compose up -d

# ====================================================================
# Шаг 1. Инициализация Config Server Replica Set
# ====================================================================
docker compose exec -T configsrv mongosh --port 27019 --quiet --eval "rs.initiate({ _id: 'configReplSet', configsvr: true, members: [ { _id: 0, host: 'configsrv:27019' } ] })"

# ====================================================================
# Шаг 2. Инициализация Replica Set shard1 (3 узла)
# ====================================================================
docker compose exec -T shard1-primary mongosh --port 27018 --quiet --eval "rs.initiate({ _id: 'shard1ReplSet', members: [ { _id: 0, host: 'shard1-primary:27018' }, { _id: 1, host: 'shard1-secondary1:27018' }, { _id: 2, host: 'shard1-secondary2:27018' } ] })"

# ====================================================================
# Шаг 3. Инициализация Replica Set shard2 (3 узла)
# ====================================================================
docker compose exec -T shard2-primary mongosh --port 27018 --quiet --eval "rs.initiate({ _id: 'shard2ReplSet', members: [ { _id: 0, host: 'shard2-primary:27018' }, { _id: 1, host: 'shard2-secondary1:27018' }, { _id: 2, host: 'shard2-secondary2:27018' } ] })"

# ====================================================================
# Шаг 4. Ожидание выбора primary (30 секунд)
# ====================================================================
Start-Sleep -Seconds 30

# ====================================================================
# Шаг 5. Добавление шардов в роутер
# ====================================================================
docker compose exec -T mongos_router mongosh --port 27017 --quiet --eval "sh.addShard('shard1ReplSet/shard1-primary:27018,shard1-secondary1:27018,shard1-secondary2:27018')"

docker compose exec -T mongos_router mongosh --port 27017 --quiet --eval "sh.addShard('shard2ReplSet/shard2-primary:27018,shard2-secondary1:27018,shard2-secondary2:27018')"

# ====================================================================
# Шаг 6. Включение шардирования базы данных somedb
# ====================================================================
docker compose exec -T mongos_router mongosh --port 27017 --quiet --eval "sh.enableSharding('somedb')"

# ====================================================================
# Шаг 7. Создание коллекции helloDoc и настройка шардирования
# ====================================================================
docker compose exec -T mongos_router mongosh --port 27017 --quiet --eval "db = db.getSiblingDB('somedb'); db.createCollection('helloDoc')"

## Шардирование коллекции helloDoc по хешированному _id 

docker compose exec -T mongos_router mongosh --port 27017 --quiet --eval "sh.shardCollection('somedb.helloDoc', { '_id': 'hashed' })"

# ====================================================================
# Шаг 8. Наполнение коллекции данными (1000 документов)
# ====================================================================
docker compose exec -T mongos_router mongosh --port 27017 --quiet --eval "db = db.getSiblingDB('somedb'); for (var i = 0; i < 1000; i++) { db.helloDoc.insertOne({ age: i, name: 'ly' + i }) }; print('Total documents:', db.helloDoc.countDocuments())"

# ====================================================================
# Шаг 9. Проверка распределения документов по шардам
# ====================================================================
docker compose exec -T mongos_router mongosh --port 27017 --quiet --eval "db = db.getSiblingDB('somedb'); db.helloDoc.getShardDistribution()"

# ====================================================================
# Шаг 10. Проверка количества реплик в каждом шарде
# ====================================================================
docker compose exec -T shard1-primary mongosh --port 27018 --quiet --eval "print(rs.status().members.length + ' members in shard1')"

docker compose exec -T shard2-primary mongosh --port 27018 --quiet --eval "print(rs.status().members.length + ' members in shard2')"

# ====================================================================
# Шаг 11. Проверка работоспособности приложения
# ====================================================================

Invoke-WebRequest -Uri "http://localhost:8080" -UseBasicParsing | Select-Object -ExpandProperty Content

# ====================================================================
# Шаг 12. Тестирование кеширования Redis
# ====================================================================
Write-Host "=== Тестирование Redis-кеширования ===" -ForegroundColor Cyan

Write-Host "Первый запрос к /helloDoc/users (холодный, без кеша):" -ForegroundColor Yellow
$time1 = Measure-Command { 
    $response1 = Invoke-WebRequest -Uri "http://localhost:8080/helloDoc/users" -UseBasicParsing
    Write-Host $response1.Content 
}
Write-Host "  Время выполнения: $($time1.TotalMilliseconds) мс" -ForegroundColor White

Write-Host "Второй запрос к /helloDoc/users (горячий, из кеша Redis):" -ForegroundColor Yellow
$time2 = Measure-Command { 
    $response2 = Invoke-WebRequest -Uri "http://localhost:8080/helloDoc/users" -UseBasicParsing
    Write-Host $response2.Content 
}
Write-Host "  Время выполнения: $($time2.TotalMilliseconds) мс" -ForegroundColor White

Write-Host "Третий запрос к /helloDoc/users (горячий, из кеша Redis):" -ForegroundColor Yellow
$time3 = Measure-Command { 
    $response3 = Invoke-WebRequest -Uri "http://localhost:8080/helloDoc/users" -UseBasicParsing
    Write-Host $response3.Content 
}
Write-Host "  Время выполнения: $($time3.TotalMilliseconds) мс" -ForegroundColor White
