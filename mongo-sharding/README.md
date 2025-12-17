# Инициализация шардирования в MongoDB (Docker Compose)

Ниже — минимальные шаги для запуска шардированного кластера MongoDB (1 config server, 2 шарда, 2 роутера `mongos`) и наполнения тестовыми данными в БД `somedb`, коллекции `helloDoc`.

## 1) Запуск кластера и API
```bash
docker compose up -d --build
# Поднимем 2 инстанса роутера
docker compose up -d --scale mongos_router=2
```

> Примечание: сервис `mongos_router` не публикует порт на хост — API подключается к нему внутри docker-сети.

## 2) Инициализация Replica Set’ов

### 2.1 Config Server (реплика `config_server`)
```bash
docker compose exec -T configSrv mongosh --port 27017 --quiet <<'EOF'
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [{ _id: 0, host: "configSrv:27017" }]
})
EOF
```

### 2.2 Shard1 (реплика `shard1`)
```bash
docker compose exec -T shard1 mongosh --port 27018 --quiet <<'EOF'
rs.initiate({
  _id: "shard1",
  members: [{ _id: 0, host: "shard1:27018" }]
})
EOF
```

### 2.3 Shard2 (реплика `shard2`)
```bash
docker compose exec -T shard2 mongosh --port 27019 --quiet <<'EOF'
rs.initiate({
  _id: "shard2",
  members: [{ _id: 0, host: "shard2:27019" }]
})
EOF
```

## 3) Подключение шардов в роутере и включение шардирования

> Для выполнения команд через один из инстансов роутера используем `--index=1`.

```bash
docker compose exec -T --index=1 mongos_router mongosh --port 27020 --quiet <<'EOF'
/* Подключаем шарды */
sh.addShard("shard1/shard1:27018")
sh.addShard("shard2/shard2:27019")

/* Включаем шардирование БД и коллекции (хэш по полю name) */
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { "name": "hashed" })

/* Наполняем данными */
use somedb
if (db.helloDoc.countDocuments() < 1000) {
  for (var i=0; i<1000; i++) db.helloDoc.insertOne({ age: i, name: "ly"+i })
}

/* Проверяем общее количество */
db.helloDoc.countDocuments()
EOF
```

## 4) Проверка распределения по шардам

### 4.1 Общее количество (через роутер)
```bash
docker compose exec -T --index=1 mongos_router mongosh --port 27020 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
EOF
```

### 4.2 Количество на каждом шарде (прямое подключение)
```bash
# shard1
docker compose exec -T shard1 mongosh --port 27018 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
EOF

# shard2
docker compose exec -T shard2 mongosh --port 27019 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
EOF
```

## 5) Проверка приложения
- HTML: `http://localhost:8080/` — общее количество и по каждому шарду.
- JSON: `http://localhost:8080/metrics`

## Полезные заметки
- Порты по умолчанию: Config Server `27017`, Shard1 `27018`, Shard2 `27019`, Mongos `27020` (внутри docker-сети).
- Масштабировать `mongos_router` можно так:
  ```bash
  docker compose up -d --scale mongos_router=3
  ```
- Инициализационные команды `addShard/enableSharding/shardCollection` безопасно выполнять один раз через любой `mongos` (в инструкциях — через `--index=1`). 
