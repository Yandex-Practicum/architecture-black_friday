param([switch]$Reset)

if ($Reset) { docker compose down -v }
docker compose up -d

function Wait-Healthy($name) {
  $id = (docker compose ps -q $name)
  Write-Host "Waiting for $name to be healthy..."
  while ($true) {
    if (-not $id) { 
      Start-Sleep -Seconds 1
      $id = (docker compose ps -q $name)
      continue
   }
    $status = docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}unknown{{end}}' $id 2>$null
    if ($LASTEXITCODE -eq 0 -and $status -eq 'healthy') { break }
    Start-Sleep -Seconds 2
  }
}

# Ждём доступности контейнеров
Wait-Healthy configSrv
Wait-Healthy mongo_shard1_1
Wait-Healthy mongo_shard1_2
Wait-Healthy mongo_shard1_3
Wait-Healthy mongo_shard2_1
Wait-Healthy mongo_shard2_2
Wait-Healthy mongo_shard2_3

# Инициализация config server
docker compose exec -T configSrv mongosh --quiet --port 27017 --eval "try{rs.status()}catch(e){rs.initiate({_id:'config_server',configsvr:true,members:[{_id:0,host:'configSrv:27017'}]})}"
docker compose exec -T configSrv mongosh --quiet --port 27017 --eval "for(;;){var h=db.hello();if(h.isWritablePrimary)break;sleep(200);}"

# Перезапустим mongos, чтобы он стабильно приконнектился к PRIMARY config RS
docker compose restart mongos_router | Out-Null
Wait-Healthy mongos_router

# Инициализация шардов
docker compose exec -T mongo_shard1_1 mongosh --quiet --port 27018 `
  --eval "try{rs.status()}catch(e){
            rs.initiate({_id:'shard1',members:[
              {_id:0,host:'mongo_shard1_1:27018'},
              {_id:1,host:'mongo_shard1_2:27018'},
              {_id:2,host:'mongo_shard1_3:27018'}]}
            )}"
docker compose exec -T mongo_shard1_1 mongosh --quiet --port 27018 `
  --eval "for(;;){var h=db.hello();if(h.isWritablePrimary)break;sleep(200);}"

docker compose exec -T mongo_shard2_1 mongosh --quiet --port 27019 `
  --eval "try{rs.status()}catch(e){
            rs.initiate({_id:'shard2',members:[
              {_id:0,host:'mongo_shard2_1:27019'},
              {_id:1,host:'mongo_shard2_2:27019'},
              {_id:2,host:'mongo_shard2_3:27019'}]}
            )}"
docker compose exec -T mongo_shard2_1 mongosh --quiet --port 27019 `
  --eval "for(;;){var h=db.hello();if(h.isWritablePrimary)break;sleep(200);}"

# Добавление шардов, включение шардинга БД и шардирование коллекции
docker compose exec -T mongos_router mongosh --quiet --port 27020 `
  --eval "if(!db.getSiblingDB('config').shards.find({_id:'shard1'}).hasNext())sh.addShard('shard1/mongo_shard1_1:27018')"
docker compose exec -T mongos_router mongosh --quiet --port 27020 `
  --eval "if(!db.getSiblingDB('config').shards.find({_id:'shard2'}).hasNext())sh.addShard('shard2/mongo_shard2_1:27019')"
docker compose exec -T mongos_router mongosh --quiet --port 27020 `
  --eval "if(!db.getSiblingDB('config').databases.find({_id:'somedb'}).hasNext())sh.enableSharding('somedb')"
docker compose exec -T mongos_router mongosh --quiet --port 27020 `
  --eval "try{sh.shardCollection('somedb.helloDoc',{name:'hashed'})}catch(e){if(!/already/.test(e))throw e}"

# Наполнение тестовыми данными
docker compose exec mongos_router mongosh --quiet --port 27020 --eval "db=db.getSiblingDB('somedb');for(var i=0;i<1000;i++)db.helloDoc.insertOne({age:i,name:'ly'+i})"

Write-Host "Done."