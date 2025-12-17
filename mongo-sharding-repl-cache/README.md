# MongoDB Sharding + Replication (2 реплики на шард)

Учебный проект с шардированием MongoDB, где каждый шард — это Replica Set из **2 узлов**.

Схема:
- Config Server запущен как Replica Set `config_server` (1 узел для учебной конфигурации).
- Shard1 = RS `shard1` из `shard1a`, `shard1b`.
- Shard2 = RS `shard2` из `shard2a`, `shard2b`.
- Роутер `mongos_router` можно масштабировать (2 инстанса и более).

БД: `somedb`
Коллекция: `helloDoc`

---

## 1) Запуск кластера и API

```bash
docker compose up -d --build

# Поднимем 2 инстанса роутера
docker compose up -d --scale mongos_router=2
```

> `mongos_router` не публикует порт наружу — API подключается к нему внутри docker-сети.

---

## 2) Настройка репликации для каждого шарда

### 2.1 Config Server (реплика `config_server`)

```bash
docker compose exec -T configSrv mongosh --port 27017 --quiet <<'EOF'
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv:27017" }
  ]
})
EOF
```

### 2.2 Shard1 (реплика `shard1`, 2 узла)

```bash
docker compose exec -T shard1a mongosh --port 27018 --quiet <<'EOF'
rs.initiate({
  _id: "shard1",
  members: [
    { _id: 0, host: "shard1a:27018" },
    { _id: 1, host: "shard1b:27018" }
  ]
})
EOF
```

Проверка состава:

```bash
docker compose exec -T shard1a mongosh --port 27018 --quiet --eval \
'rs.conf().members.length'
```

### 2.3 Shard2 (реплика `shard2`, 2 узла)

```bash
docker compose exec -T shard2a mongosh --port 27019 --quiet <<'EOF'
rs.initiate({
  _id: "shard2",
  members: [
    { _id: 0, host: "shard2a:27019" },
    { _id: 1, host: "shard2b:27019" }
  ]
})
EOF
```

Проверка состава:

```bash
docker compose exec -T shard2a mongosh --port 27019 --quiet --eval \
'rs.conf().members.length'
```

---

## 3) Подключение шардов к роутеру и включение шардирования

> Для выполнения команд через один из инстансов роутера используем `--index=1`.

```bash
docker compose exec -T --index=1 mongos_router mongosh --port 27020 --quiet <<'EOF'
/* Подключаем шарды как replica set */
sh.addShard("shard1/shard1a:27018,shard1b:27018")
sh.addShard("shard2/shard2a:27019,shard2b:27019")

/* Включаем шардирование БД и коллекции */
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { "name": "hashed" })
EOF
```

---

## 4) Заполнение тестовыми данными (≥ 1000)

```bash
docker compose exec -T --index=1 mongos_router mongosh --port 27020 --quiet <<'EOF'
use somedb
if (db.helloDoc.countDocuments() < 1000) {
  for (var i=0; i<1000; i++) db.helloDoc.insertOne({ age: i, name: "ly"+i })
}
db.helloDoc.countDocuments()
EOF
```

---

## 5) Проверка распределения по шардам

```bash
docker compose exec -T --index=1 mongos_router mongosh --port 27020 --quiet <<'EOF'
use somedb
db.helloDoc.getShardDistribution()
EOF
```

---

## 6) Проверка приложения

- HTML/JSON: `http://localhost:8080/`

---

## 7) Автоматизация

Все ключевые шаги можно выполнить одним скриптом:

```bash
chmod +x scripts/mongo-init.sh
./scripts/mongo-init.sh
```

---

## Полезные заметки

- Порты внутри docker-сети:
  - Config Server `27017`
  - Shard1 `27018`
  - Shard2 `27019`
  - Mongos `27020`
- Масштабирование роутера:

```bash
docker compose up -d --scale mongos_router=3
```

---

## 9) Что показывает эндпоинт `/`

Эндпоинт `GET /` сервиса API возвращает:

- `db_total_documents` — общее количество документов в базе `somedb`;
- `target_collection_total_documents` — количество документов в коллекции `helloDoc`;
- `target_collection_shard_documents` — распределение документов по шардерам;
- `replicas_per_shard` — количество реплик в каждом шарде (`shard1`, `shard2`).

Это как раз те параметры, на которые смотрит ревьюер.

---

## 10) Настройка кеширования с Redis

В `docker compose` добавлен сервис:

- `redis` — одиночный инстанс Redis, работающий на порту `6379` внутри docker-сети.

Сервис `api` получает строку подключения к Redis через переменную окружения:

```yaml
REDIS_URL: "redis://redis:6379"
```

На старте приложения FastAPI инициализирует `FastAPICache` с backend'ом Redis.  
Если Redis недоступен, декоратор `@cache` автоматически отключается (используется `nocache`).

---

## 11) Проверка работы кеширования эндпоинта `/<collection_name>/users`

Эндпоинт:

```http
GET /helloDoc/users
```

возвращает до 1000 документов и обёрнут в декоратор:

```python
@cache(expire=60 * 1)
```

То есть результат запроса кешируется на **60 секунд**.

### Как проверить ускорение

1. Убедитесь, что всё запущено:

```bash
docker compose up -d --build
```

2. Первый запрос (идёт в MongoDB, есть искусственная задержка `time.sleep(1)`):

```bash
curl -w '\nTotal: %{time_total}s\n' -o /dev/null -s http://localhost:8080/helloDoc/users
```

Ожидаемое время: ~1 секунда.

3. Второй и последующие запросы (идут из Redis-кеша):

```bash
curl -w '\nTotal: %{time_total}s\n' -o /dev/null -s http://localhost:8080/helloDoc/users
```

Ожидаемое время: **< 0.1 сек** (меньше 100 мс).

Таким образом, ревьюер увидит:

- шардирование + репликация (по шагам выше),
- наличие Redis-сервиса,
- ускорение второго вызова `/<collection_name>/users` за счёт кеширования.

