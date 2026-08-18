## mongo-sharding - Шардирование MongoDB

## Описание
Этот проект демонстрирует реализацию шардирования в MongoDB для горизонтального масштабирования.  
В основе лежит приложение **pymongo-api**, которое работает с шардированной базой данных.

## Архитектура
- **2 шарда** (shard1, shard2) для распределения данных
- **3 Config Servers** для хранения метаданных кластера
- **1 Mongos Router** для маршрутизации запросов к шардам
- **API приложение** на FastAPI + PyMongo

## Как запустить

### 1. Запуск кластера
Запускаем все сервисы (MongoDB шарды, Config Servers, Mongos и API):

```shell
docker compose up -d
```

Откройте в браузере http://localhost:8080

## Доступные эндпоинты

Список доступных эндпоинтов, swagger http://localhost:8080/docs

### Проверка статуса контейнеров

```shell
docker compose ps
```

Ожидаемый результат: все контейнеры в статусе `Up`, а `mongodb_init` в статусе `Exited (0)` (успешно выполнен).

### Проверка количества документов

Общее количество документов:

```shell
docker compose exec -T mongos_router mongosh --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

Количество документов в шарде 1:

```shell
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

Количество документов в шарде 2:

```shell
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

Ожидаемый результат:
- Общее количество документов ≥ 1000
- Документы распределены между шардами (в каждом шарде > 0 документов)

### Проверка через API

Получение общего количества документов:

```shell
curl http://localhost:8080/helloDoc/count
```


### Если автоматическая инициализация не сработала

Выполните инициализацию вручную:

```shell
./scripts/mongo-init.sh
```

```shell
docker compose logs mongodb_init
```

Логи API:

```shell
docker compose logs pymongo_api
```

Логи Mongos:

```shell
docker compose logs mongos_router
```

### Устранение неполадок

Если контейнеры не запускаются:

```shell
docker compose logs
docker compose down -v
docker compose up -d
```

Если порты заняты:

```shell
sudo lsof -i :27017
sudo lsof -i :8080
docker compose down
```
