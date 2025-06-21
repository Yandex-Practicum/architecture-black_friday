# MongoDB

## Состав

- `configsvr` — Конфигурационный сервер (replSet: `configReplSet`)
- `shard1ReplSet`:
  - `shard1-primary`
  - `shard1-secondary1`
  - `shard1-secondary2`
- `shard2ReplSet`:
  - `shard2-primary`
  - `shard2-secondary1`
  - `shard2-secondary2`
- `mongos` — MongoDB Router
- `redis` — Кеширующий сервер
- `pymongo_api` — API-сервис (Python + FastAPI), подключён к `mongos`, использует Redis

## Запуск

```bash
docker compose up -d
```

## Инициализация реплик

### 1. Репликация `configsvr`

```bash
docker exec -it configsvr mongosh --port 27019
```

```shell
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [
    { _id: 0, host: "configsvr:27019" }
  ]
})
```

### 2. Репликация `shard1ReplSet`

```bash
docker exec -it shard1-primary mongosh --port 27018
```

```shell
rs.initiate({
  _id: "shard1ReplSet",
  members: [
    { _id: 0, host: "shard1-primary:27018" },
    { _id: 1, host: "shard1-secondary1:27021" },
    { _id: 2, host: "shard1-secondary2:27022" }
  ]
})
```

### 3. Репликация `shard2ReplSet`

```bash
docker exec -it shard2-primary mongosh --port 27023
```

```shell
rs.initiate({
  _id: "shard2ReplSet",
  members: [
    { _id: 0, host: "shard2-primary:27023" },
    { _id: 1, host: "shard2-secondary1:27024" },
    { _id: 2, host: "shard2-secondary2:27025" }
  ]
})
```

## Подключение к `mongos` и добавление шардов

```bash
docker exec -it mongos mongosh --port 27017
```

```shell
sh.addShard("shard1ReplSet/shard1-primary:27018,shard1-secondary1:27021,shard1-secondary2:27022")
sh.addShard("shard2ReplSet/shard2-primary:27023,shard2-secondary1:27024,shard2-secondary2:27025")
```

## Настройка шардирования базы и коллекции

```shell
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { _id: "hashed" })
```

## Заполняем MongoDB данными

```bash
./mongo-init.sh
```

## Проверка

```shell
sh.status()
```

## Проверка работы API

```bash
curl http://localhost:8080
```

## Остановка и удаление всех данных

```bash
docker compose down -v
```
