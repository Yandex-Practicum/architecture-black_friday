# Mongo sharding (Задание 2)

## Что разворачивается
- MongoDB config server (RS `config_server`, порт 27017)
- Два шарда (`shard1:27018`, `shard2:27019`), каждый как **replicaset** из одного члена
- Роутер `mongos` (порт 27020)
- Приложение `kazhem/pymongo_api:1.0.0` (порт 8080)

Шардирование коллекции `somedb.helloDoc` по ключу `{ name: "hashed" }` с наполнением 1000 документов.

## Запуск

Требования: Docker + Docker Compose, ≥2 CPU и ≥4 ГБ RAM.

```bash
docker compose up -d
```

## Проверка количества документов

```bash
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
db.helloDoc.getShardDistribution()
EOF
```