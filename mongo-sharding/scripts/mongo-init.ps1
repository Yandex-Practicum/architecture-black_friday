param([switch]$Reset)

if ($Reset) { docker compose down -v }
docker compose up -d

function Wait-Healthy($name) {
  Write-Host "Waiting for $name to be healthy..."
  while ($true) {
    $status = docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}unknown{{end}}' $name 2>$null
    if ($LASTEXITCODE -eq 0 -and $status -eq 'healthy') { break }
    Start-Sleep -Seconds 2
  }
}

# Ждём доступности контейнеров
Wait-Healthy configSrv
Wait-Healthy mongo_shard1
Wait-Healthy mongo_shard2

# Инициализация config server
docker exec configSrv mongosh --quiet --port 27017 --eval "try{rs.status()}catch(e){rs.initiate({_id:'config_server',configsvr:true,members:[{_id:0,host:'configSrv:27017'}]})}"
docker exec configSrv mongosh --quiet --port 27017 --eval "for(;;){var h=db.hello();if(h.isWritablePrimary)break;sleep(200);}"

# Перезапустим mongos, чтобы он стабильно приконнектился к PRIMARY config RS
docker restart mongos_router | Out-Null
Wait-Healthy mongos_router

# Инициализация шардов
docker exec mongo_shard1 mongosh --quiet --port 27018 --eval "try{rs.status()}catch(e){rs.initiate({_id:'shard1',members:[{_id:0,host:'mongo_shard1:27018'}]})}"
docker exec mongo_shard1 mongosh --quiet --port 27018 --eval "for(;;){var h=db.hello();if(h.isWritablePrimary)break;sleep(200);}"

docker exec mongo_shard2 mongosh --quiet --port 27019 --eval "try{rs.status()}catch(e){rs.initiate({_id:'shard2',members:[{_id:0,host:'mongo_shard2:27019'}]})}"
docker exec mongo_shard2 mongosh --quiet --port 27019 --eval "for(;;){var h=db.hello();if(h.isWritablePrimary)break;sleep(200);}"

# Добавление шардов, включение шардинга БД и шардирование коллекции
docker exec mongos_router mongosh --quiet --port 27020 --eval "if(!db.getSiblingDB('config').shards.find({_id:'shard1'}).hasNext())sh.addShard('shard1/mongo_shard1:27018')"
docker exec mongos_router mongosh --quiet --port 27020 --eval "if(!db.getSiblingDB('config').shards.find({_id:'shard2'}).hasNext())sh.addShard('shard2/mongo_shard2:27019')"
docker exec mongos_router mongosh --quiet --port 27020 --eval "if(!db.getSiblingDB('config').databases.find({_id:'somedb'}).hasNext())sh.enableSharding('somedb')"
docker exec mongos_router mongosh --quiet --port 27020 --eval "try{sh.shardCollection('somedb.helloDoc',{name:'hashed'})}catch(e){if(!/already/.test(e))throw e}"

# Наполнение тестовыми данными
docker exec mongos_router mongosh --quiet --port 27020 --eval "db=db.getSiblingDB('somedb');for(var i=0;i<1000;i++)db.helloDoc.insert({age:i,name:'ly'+i})"

Write-Host "Done."