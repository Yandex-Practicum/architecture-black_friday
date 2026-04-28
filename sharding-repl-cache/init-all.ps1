Write-Host "--- 1. Инициализация Config Server ---" -ForegroundColor Cyan
docker exec -it configSrv mongosh --port 27119 --eval "rs.initiate({_id: 'configReplSet', members: [{_id: 0, host: 'configSrv:27119'}]})"

Write-Host "--- Ожидание 10с для стабилизации Config Server ---"
Start-Sleep -s 10

Write-Host "--- 2. Инициализация Shard 1 (Replica Set) ---" -ForegroundColor Cyan
docker exec -it shard1-1 mongosh --port 27111 --eval "rs.initiate({_id: 'shard1ReplSet', members: [{_id: 0, host: 'shard1-1:27111'}, {_id: 1, host: 'shard1-2:27112'}, {_id: 2, host: 'shard1-3:27113'}]})"

Write-Host "--- 3. Инициализация Shard 2 (Replica Set) ---" -ForegroundColor Cyan
docker exec -it shard2-1 mongosh --port 27121 --eval "rs.initiate({_id: 'shard2ReplSet', members: [{_id: 0, host: 'shard2-1:27121'}, {_id: 1, host: 'shard2-2:27122'}, {_id: 2, host: 'shard2-3:27123'}]})"

Write-Host "--- Ожидание 15с для выбора Primary в шардах ---"
Start-Sleep -s 15

Write-Host "--- 4. Регистрация шардов в Mongos ---" -ForegroundColor Cyan
docker exec -it mongos mongosh --port 27117 --eval "sh.addShard('shard1ReplSet/shard1-1:27111'); sh.addShard('shard2ReplSet/shard2-1:27121');"

Write-Host "--- 5. Статус кластера ---" -ForegroundColor Green
docker exec -it mongos mongosh --port 27117 --eval "sh.status()"