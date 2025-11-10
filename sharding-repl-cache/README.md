# MongoDB Sharded Cluster с Репликацией и Кешированием

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
- **redis:6379** - кеш

## Запуск

### 1. Запуск всех сервисов

```shell
docker compose up -d

```

### 2. Инициализация репликации и шардирования

```shell
./scripts/mongo-init.sh
```

### 3. Проверка работы

### Веб-интерфейс

- **Главная**: http://localhost:8080
- **Swagger документация**: http://localhost:8080/docs

#### Тестирование кеширования

Первый запрос ~1 сек

```shell
time curl -s http://localhost:8080/helloDoc/users > /dev/null
```

Второй запрос <100мс (из кеша)

```shell
time curl -s http://localhost:8080/helloDoc/users > /dev/null
```