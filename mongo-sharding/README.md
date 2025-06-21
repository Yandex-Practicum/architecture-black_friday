# MongoDB

## Состав

- `configsvr` — Конфигурационный сервер (replSet: `configReplSet`)
- `shard1` — Первый шард (replSet: `shard1ReplSet`)
- `shard2` — Второй шард (replSet: `shard2ReplSet`)
- `mongos` — MongoDB router
- `pymongo_api` — API-сервис (Python + FastAPI), подключён к `mongos`

## Запуск кластера

```bash
docker compose up -d
```

## Заполняем mongo данными

```shell
./mongo-init.sh
```

## Подключиться к mongos и добавить шарды

```bash
docker exec -it mongos mongosh --port 27017
```

```shell
sh.addShard("shard1ReplSet/shard1:27018")
sh.addShard("shard2ReplSet/shard2:27020")
```

---

## Настройка шардирования базы и коллекции

```shell
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { _id: "hashed" })
```

---

## Проверка кластера

```shell
sh.status()
```

---

## Проверка работы API

После запуска можно проверить API:

```bash
curl http://localhost:8080
```

---

## Остановка и удаление данных

```bash
docker compose down -v
```
