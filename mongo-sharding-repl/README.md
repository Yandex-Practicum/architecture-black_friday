# Mongo sharding + replication (Задание 3)

## Состав кластера
- MongoDB config server — реплика-сет `configReplSet` из 1 ноды (порт 27017). На проде бы сделали несколько нод и для config-сервера
- Shard1 — реплика-сет `shard1` из 3 нод: `shard1-1, shard1-2, shard1-3` (порт 27018)
- Shard2 — реплика-сет `shard2` из 3 нод: `shard2-1, shard2-2, shard2-3` (порт 27019)
- Mongos router: порт 27020
- Приложение: `kazhem/pymongo_api:1.0.0` (порт 8080)

Коллекция `somedb.helloDoc` шардирована по ключу `{ name: "hashed" }`. Наполняется 1000 документов.

## Запуск
```bash
docker compose up -d
```

## Общее число документов и распределение по шардам

```bash
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
db.helloDoc.getShardDistribution()
EOF
```

## Кол-во членов RS для каждого шарда (должно быть 3)

```bash
docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval "rs.status().members.length"
docker compose exec -T shard2-1 mongosh --port 27019 --quiet --eval "rs.status().members.length"
```
