## Инициализация шардирования

### 1. Поднять кластер

```shell
docker compose up -d
```

Дождитесь, пока `configSrv`, `shard1` и `shard2` перейдут в состояние `healthy`
(`mongos` пока будет `unhealthy` - он оживёт после инициализации конфиг-сервера):

```shell
docker compose ps
```

### 2. Инициировать реплика-сет конфигурационного сервера

```shell
docker compose exec -T configSrv mongosh --port 27019 --quiet <<'EOF'
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [{ _id: 0, host: "configSrv:27019" }]
})
EOF
```

Дождитесь, пока `mongos` перейдёт в `healthy`:

```shell
docker compose ps
```

### 3. Инициировать реплика-сеты шардов

По одному узлу на шард — задел под задание 3 (репликацию).

```shell
docker compose exec -T shard1 mongosh --port 27018 --quiet <<'EOF'
rs.initiate({
  _id: "shard1",
  members: [{ _id: 0, host: "shard1:27018" }]
})
EOF
```

```shell
docker compose exec -T shard2 mongosh --port 27018 --quiet <<'EOF'
rs.initiate({
  _id: "shard2",
  members: [{ _id: 0, host: "shard2:27018" }]
})
EOF
```

### 4. Зарегистрировать шарды и включить шардирование

```shell
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
sh.addShard("shard1/shard1:27018")
sh.addShard("shard2/shard2:27018")
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { _id: "hashed" })
EOF
```

### 5. Наполнить коллекцию

```shell
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
for (let i = 0; i < 1000; i++) db.helloDoc.insertOne({ age: i, name: "ly" + i })
EOF
```

## Как проверить

1. Откройте http://localhost:8080

2. Количество документов на каждом шарде:

```shell
docker compose exec -T shard1 mongosh --port 27018 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
EOF
```

```shell
docker compose exec -T shard2 mongosh --port 27018 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
EOF
```

## Остановить

```shell
docker compose down -v
```
