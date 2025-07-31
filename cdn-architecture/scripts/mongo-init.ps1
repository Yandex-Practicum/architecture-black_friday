# инициализация CDN архитектуры с MongoDB

Write-Host "инициализация CDN архитектуры для 'Мобильный мир'" -ForegroundColor Green

Write-Host "настройка config сервера..."
docker compose exec configsvr mongosh --port 27019 --eval "rs.initiate({ _id: 'configReplSet', configsvr: true, members: [{ _id: 0, host: 'configsvr:27019' }] })"

Write-Host "настройка shard1 с 3 копиями..."
docker compose exec shard1 mongosh --port 27018 --eval "rs.initiate({ _id: 'shard1ReplSet', members: [{ _id: 0, host: 'shard1:27018' }, { _id: 1, host: 'shard1-secondary1:27028' }, { _id: 2, host: 'shard1-secondary2:27038' }] })"

Write-Host "настройка shard2 с 3 копиями..."
docker compose exec shard2 mongosh --port 27020 --eval "rs.initiate({ _id: 'shard2ReplSet', members: [{ _id: 0, host: 'shard2:27020' }, { _id: 1, host: 'shard2-secondary1:27030' }, { _id: 2, host: 'shard2-secondary2:27040' }] })"

Write-Host "ожидание запуска реплик..."
Start-Sleep -Seconds 15

Write-Host "добавление шардов и включение шардирования..."
docker compose exec mongos mongosh --port 27017 --eval "sh.addShard('shard1ReplSet/shard1:27018'); sh.addShard('shard2ReplSet/shard2:27020'); sh.enableSharding('somedb'); sh.shardCollection('somedb.helloDoc', { _id: 'hashed' })"

Write-Host "добавление данных в коллекцию..."
docker compose exec mongos mongosh --port 27017 somedb --eval "for (let i = 0; i < 1500; i++) { db.helloDoc.insertOne({ age: i, name: 'ly' + i }) }"

Write-Host "инициализация завершена!" -ForegroundColor Green
Write-Host ""
Write-Host "CDN узлы доступны по адресам:" -ForegroundColor Cyan
Write-Host "   Европа: http://localhost:8091" -ForegroundColor Yellow
Write-Host "   Азия:   http://localhost:8092" -ForegroundColor Yellow
Write-Host "   Америка: http://localhost:8093" -ForegroundColor Yellow
Write-Host "   Глобальный: http://localhost:8080" -ForegroundColor Yellow
Write-Host ""
Write-Host "API серверы:" -ForegroundColor Cyan
Write-Host "   API 1: http://localhost:8001" -ForegroundColor Yellow
Write-Host "   API 2: http://localhost:8002" -ForegroundColor Yellow
Write-Host "   API 3: http://localhost:8003" -ForegroundColor Yellow
Write-Host ""
Write-Host "мониторинг:" -ForegroundColor Cyan
Write-Host "   Consul UI: http://localhost:8500" -ForegroundColor Yellow
Write-Host "   CDN статус: http://localhost:8091/cdn-status" -ForegroundColor Yellow 