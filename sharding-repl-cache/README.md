# MongoDB Sharding + Replication + Redis Cache

Проект с настройкой шардирования MongoDB (2 шарда), репликацией (3 реплики на шард) и кешированием через Redis.

## Архитектура

### Config Server Replica Set
- **configSrv1, configSrv2, configSrv3** — Config Server ReplicaSet (порт 27017)

### Shard 1 Replica Set
- **shard1-1, shard1-2, shard1-3** — Шард 1 ReplicaSet (порт 27018)

### Shard 2 Replica Set
- **shard2-1, shard2-2, shard2-3** — Шард 2 ReplicaSet (порт 27018)

### Router, Cache & API
- **mongos_router** — MongoDB Router (порт 27020)
- **redis** — Redis Cache (порт 6379)
- **pymongo_api** — API приложение (порт 8080)

**Всего: 12 контейнеров**

## Запуск

### 1. Запустить контейнеры

```bash
docker compose up -d
```

### 2. Инициализировать Config Server Replica Set

```bash
docker compose exec -T configSrv1 mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "config_rs",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv1:27017" },
    { _id: 1, host: "configSrv2:27017" },
    { _id: 2, host: "configSrv3:27017" }
  ]
})
EOF
```

### 3. Инициализировать Shard 1 Replica Set

```bash
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1_rs",
  members: [
    { _id: 0, host: "shard1-1:27018" },
    { _id: 1, host: "shard1-2:27018" },
    { _id: 2, host: "shard1-3:27018" }
  ]
})
EOF
```

### 4. Инициализировать Shard 2 Replica Set

```bash
docker compose exec -T shard2-1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard2_rs",
  members: [
    { _id: 0, host: "shard2-1:27018" },
    { _id: 1, host: "shard2-2:27018" },
    { _id: 2, host: "shard2-3:27018" }
  ]
})
EOF
```

### 5. Подождать инициализации реплик (20 секунд)

```bash
sleep 20
```

### 6. Добавить шарды в кластер

```bash
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1_rs/shard1-1:27018,shard1-2:27018,shard1-3:27018")
sh.addShard("shard2_rs/shard2-1:27018,shard2-2:27018,shard2-3:27018")
EOF
```

### 7. Включить шардирование для базы данных

```bash
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.enableSharding("somedb")
EOF
```

### 8. Создать коллекцию с шардированием

```bash
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
use somedb
db.createCollection("helloDoc")
sh.shardCollection("somedb.helloDoc", { "name": "hashed" })
EOF
```

### 9. Наполнить коллекцию тестовыми данными (1000+ документов)

```bash
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
use somedb
for (var i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({ name: "user_" + i, age: Math.floor(Math.random() * 100) })
}
EOF
```

## Проверка

### Проверить статус шардирования

```bash
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.status()
EOF
```

### Проверить статус репликации Shard 1

```bash
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.status()
EOF
```

### Проверить статус репликации Shard 2

```bash
docker compose exec -T shard2-1 mongosh --port 27018 --quiet <<EOF
rs.status()
EOF
```

### Проверить количество документов в каждом шарде

```bash
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

```bash
docker compose exec -T shard2-1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

### Проверить приложение

Открыть в браузере: http://localhost:8080

Или выполнить:

```bash
curl http://localhost:8080
```

Должен вернуться JSON с информацией о MongoDB, включая:
- `mongo_topology_type: "Sharded"`
- `shards` со списком шардов
- `collections.helloDoc.documents_count` >= 1000
- `cache_enabled: true`

## Проверка кеширования

Кеширование работает для эндпоинта `/<collection_name>/users`.

### Первый запрос (без кеша, ~1 секунда)

```bash
time curl http://localhost:8080/helloDoc/users
```

### Второй запрос (из кеша, <100мс)

```bash
time curl http://localhost:8080/helloDoc/users
```

Второй и последующие запросы должны выполняться значительно быстрее (<100мс), так как данные берутся из Redis кеша.

### Проверить ключи в Redis

```bash
docker compose exec -T redis redis-cli KEYS "api:cache:*"
```

## Остановка

```bash
docker compose down
```

Для полной очистки (включая volumes):

```bash
docker compose down -v
```
