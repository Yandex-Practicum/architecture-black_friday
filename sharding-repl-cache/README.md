# sharding-repl-cache

## Описание

Проект демонстрирует реализацию шардирования с репликацией и кешированием в MongoDB.  
Каждый шард состоит из 3 реплик для обеспечения отказоустойчивости.  
Добавлен Redis для кеширования запросов.

## Архитектура

- **Config Servers**: 3 ноды (`config_server_1`, `config_server_2`, `config_server_3`)
- **Шард 1**: 3 реплики (`shard1_1`, `shard1_2`, `shard1_3`)
- **Шард 2**: 3 реплики (`shard2_1`, `shard2_2`, `shard2_3`)
- **Mongos Router**: 1 нода (`mongos_router`)
- **Redis**: 1 нода (`redis`)
- **API**: 1 нода (`pymongo_api`)

## Как запустить

Запускаем кластер:

```shell
docker compose up -d
```

Инициализация выполняется автоматически.

При необходимости выполнить вручную:

```shell
./scripts/mongo-init.sh
```

## Как проверить

### Проверка количества документов

**Общее количество документов:**

```shell
docker compose exec -T mongos_router mongosh --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

**Количество документов в шарде 1:**

```shell
docker compose exec -T shard1_1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

**Количество документов в шарде 2:**

```shell
docker compose exec -T shard2_1 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

### Проверка репликации

**Статус репликации шарда 1:**

```shell
docker compose exec -T shard1_1 mongosh --port 27018 --quiet --eval "rs.status()"
```

**Статус репликации шарда 2:**

```shell
docker compose exec -T shard2_1 mongosh --port 27019 --quiet --eval "rs.status()"
```

### Проверка кеширования

**Первый запрос (без кеша, ~1 секунда):**

```shell
time curl http://localhost:8080/helloDoc/users
```

**Второй запрос (с кешем, <100 мс):**

```shell
time curl http://localhost:8080/helloDoc/users
```

### Проверка через API

**Корневой эндпоинт:**

```shell
curl http://localhost:8080/
```

**Количество документов в коллекции:**

```shell
curl http://localhost:8080/helloDoc/count
```

**Swagger документация:**

http://localhost:8080/docs

## Доступные эндпоинты

| Эндпоинт | Метод | Описание |
|---|---|---|
| `/` | GET | Информация о кластере |
| `/{collection_name}/count` | GET | Количество документов в коллекции |
| `/{collection_name}/users` | GET | Список пользователей (с кешированием) |
| `/{collection_name}/users` | POST | Создание пользователя |
| `/{collection_name}/users/{name}` | GET | Получение пользователя по имени |

## Проверка работы с пользователями

### Создание пользователя

```shell
curl -X POST http://localhost:8080/helloDoc/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "age": 30}'
```

### Получение списка пользователей (с кешем)

```shell
curl http://localhost:8080/helloDoc/users
```

### Получение пользователя по имени

```shell
curl http://localhost:8080/helloDoc/users/Alice
```

## Остановка проекта

```shell
docker compose down -v
```
