# MongoDB Sharding

## Контейнеры

- **pymongo_api** (порт 8080) - веб-приложение
- **mongo_config_srv** (порт 27019) - хранит метаданные кластера
- **mongo_router** (порт 27017) - маршрутизатор запросов между шардами
- **shard1** (порт 27018) - первый шард данных
- **shard2** (порт 27020) - второй шард данных

## Запуск

### 1. Запуск всех сервисов

```shell
docker compose up -d
```

### 2. Инициализация шардирования

```shell
./scripts/mongo-init.sh
```

## Проверка работы

### Веб-интерфейс

- **Главная**: http://localhost:8080
- **Swagger документация**: http://localhost:8080/docs

### Статус кластера

```shell
docker compose exec -T mongos mongosh --port 27017 --quiet --eval "sh.status()"
```

### Распределение данных по шардам

```shell
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
use somedb
db.helloDoc.getShardDistribution()
EOF
```

### Количество документов в каждом шарде

#### Shard 1:

```shell
docker compose exec -T shard1 mongosh --port 27018 --quiet --eval "use somedb" --eval "db.helloDoc.countDocuments()"
```

#### Shard 2:

```shell
docker compose exec -T shard2 mongosh --port 27020 --quiet --eval "use somedb" --eval "db.helloDoc.countDocuments()"
```

### Общее количество через mongo_router:

```shell
docker compose exec -T mongo_router mongosh --port 27017 --quiet --eval "use somedb" --eval "db.helloDoc.countDocuments()"
```