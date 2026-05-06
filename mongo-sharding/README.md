# MongoDB Sharding

Проект с настройкой шардирования MongoDB (2 шарда).

## Архитектура

- **configSrv** — Config Server (порт 27017)
- **shard1** — Шард 1 (порт 27018)
- **shard2** — Шард 2 (порт 27019)
- **mongos_router** — MongoDB Router (порт 27020)
- **pymongo_api** — API приложение (порт 8080)

## Запуск

### 1. Запустить контейнеры

```bash
docker compose up -d
```

### 2. Инициализировать Config Server

```bash
docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "config_rs",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv:27017" }
  ]
})
EOF
```

### 3. Инициализировать Shard 1

```bash
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1_rs",
  members: [
    { _id: 0, host: "shard1:27018" }
  ]
})
EOF
```

### 4. Инициализировать Shard 2

```bash
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
rs.initiate({
  _id: "shard2_rs",
  members: [
    { _id: 0, host: "shard2:27019" }
  ]
})
EOF
```

### 5. Подождать инициализации (10-15 секунд)

```bash
sleep 15
```

### 6. Добавить шарды в кластер

```bash
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1_rs/shard1:27018")
sh.addShard("shard2_rs/shard2:27019")
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

### Проверить количество документов в каждом шарде

```bash
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

```bash
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
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

## Остановка

```bash
docker compose down
```

Для полной очистки (включая volumes):

```bash
docker compose down -v
```
