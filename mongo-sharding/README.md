# TASK 1

## MongoDB Sharding (2 shards + config server + mongos) + pymongo_api

Состав стенда:

- `configsvr` — config server (replica set `configReplSet`, порт `27019`)
- `shard1` — shard replica set `shard1ReplSet` (1 нода, порт `27018`)
- `shard2` — shard replica set `shard2ReplSet` (1 нода, порт `27018`)
- `mongos` — router (порт `27017`)
- `pymongo_api` — приложение, подключается к `mongos`

---

## Как запустить Автоматически

```bash
cd ./mongo-sharding
.\init-sharding.sh
```

## Как запустить Вручную

### 0. переход в директорию

```bash
cd ./mongo-sharding
```

### 1.Запуск

```bash
docker compose up -d --build
docker compose ps
```

### 2.Инициализация config replica set

```bash
docker compose exec -T configsvr mongosh --port 27019 --quiet <<'EOF'
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [{ _id: 0, host: "configsvr:27019" }]
})
rs.status().ok
EOF
```

### 3.Инициализация replica set для shard1

```bash
docker compose exec -T shard1 mongosh --port 27018 --quiet <<'EOF'
rs.initiate({
  _id: "shard1ReplSet",
  members: [{ _id: 0, host: "shard1:27018" }]
})
rs.status().ok
EOF
```

### 4.Инициализация replica set для shard2

```bash
docker compose exec -T shard2 mongosh --port 27018 --quiet <<'EOF'
rs.initiate({
  _id: "shard2ReplSet",
  members: [{ _id: 0, host: "shard2:27018" }]
})
rs.status().ok
EOF
```

### 5.Проверка, что mongos — это роутер

```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
db.hello()
EOF
```

В ответе должно быть "msg": "isdbgrid" — это признак mongos

### 6.Добавление шардов в кластер

```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
sh.addShard("shard1ReplSet/shard1:27018")
sh.addShard("shard2ReplSet/shard2:27018")
sh.status()
EOF
```

### 7.Включение шардирования и шардирование коллекции helloDoc

```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb

// если раньше уже вставляли данные без шардинга — удаляем коллекцию
db.helloDoc.drop()

// включаем шардирование базы
sh.enableSharding("somedb")

// создаём индекс под shard key
db.helloDoc.createIndex({ _id: "hashed" })

// шардируем коллекцию
sh.shardCollection("somedb.helloDoc", { _id: "hashed" })

// проверка: коллекция должна стать sharded
sh.status()
EOF
```

### 8.Заполнение коллекции

```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
for (let i = 0; i < 2000; i++) {
  db.helloDoc.insertOne({age:i, name:"ly"+i})
}
db.helloDoc.countDocuments()
EOF
```

### 9.1.Проверка, что коллекция шардирована и как распределились данные

```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
db.helloDoc.getShardDistribution()
EOF
```

### 9.2.Проверка общего количества документов через mongos

```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
EOF
```
