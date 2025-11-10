# MongoDB Sharded Cluster с Репликацией

## Контейнеры

- **pymongo_api:8080** - веб-приложение
- **mongo_config_srv:27019** - хранит метаданные кластера (в режиме replica set)
- **mongo_router:27017** - маршрутизатор запросов между шардами
- **shard1_primary:27018** - первый шард, primary, приоритет 10
- **shard1_secondary1:27018** - реплика первого шарда, secondary, приоритет 5
- **shard1_secondary2:27018** - реплика первого шарда, secondary, приоритет 1
- **shard2_primary:27020** - второй шард, primary, приоритет 10
- **shard2_secondary1:27020** - реплика второго шарда, secondary, приоритет 5
- **shard2_secondary2:27020** - реплика второго шарда, secondary, приоритет 1

## Запуск

### 1. Запуск всех сервисов

```shell
docker compose up -d
```

### 2. Инициализация репликации и шардирования

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
````

### Проверка Config Server

```shell
docker compose exec -T configsvr mongosh --port 27019 --quiet --eval "db.adminCommand('ping')"
```

### Статус Shard 1 Replica Set

```shell
docker compose exec -T shard1_primary mongosh --port 27018 --quiet --eval "rs.status()"
```

### Статус Shard 2 Replica Set

```shell
docker compose exec -T shard2_primary mongosh --port 27020 --quiet --eval "rs.status()"
```

### Проверка Primary/Secondary узлов

```shell
docker compose exec -T shard1_primary mongosh --port 27018 --quiet --eval "db.hello().isWritablePrimary"  
docker compose exec -T shard2_primary mongosh --port 27020 --quiet --eval "db.hello().isWritablePrimary"
```
