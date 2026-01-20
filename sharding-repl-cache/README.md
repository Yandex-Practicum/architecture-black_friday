# sharding-repl-cache

Проект демонстрирует **шардирование MongoDB с репликацией и кешированием запросов через Redis** ([третий вариант схемы](../docs/diagrams/sprint_4_task_1_v_3.drawio)):


* MongoDB Sharding
* Реплики у каждого шарда (Replica Set)
* Redis для кеширования запросов приложения

---

## Архитектура

### MongoDB

* **Config Server** (Replica Set из 1 узла)
* **Shard 1** — Replica Set из 3 узлов
* **Shard 2** — Replica Set из 3 узлов
* **mongos** — роутер

### Кеширование

* **Redis** используется для кеширования запросов приложения
* Кеш включается автоматически через переменную окружения `REDIS_URL`
* Кешируется эндпоинт:

```
/<collection_name>/users
```

---

## Требования

* Docker
* Docker Compose v2+

---

## Запуск проекта

```bash
docker compose up -d
```

Проверьте, что все контейнеры запущены и находятся в статусе `healthy`:

```bash
docker compose ps
```

---

## Инициализация шардирования

Все инициализационные контейнеры запускаются автоматически:

1. Инициализируется Replica Set config server
2. Инициализируются Replica Set каждого шарда
3. Шарды добавляются в кластер через `mongos`

Дополнительных ручных действий не требуется.

---

## Инициализация данных

Для наполнения базы данными используйте скрипт:

```bash
#!/bin/bash

docker compose exec -T mongos mongosh --port 27020 --quiet <<EOF
use somedb
for (var i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({ age: i, name: "user" + i })
}
EOF
```

После выполнения в базе `somedb` будет создана коллекция `helloDoc` с 1000 документами.

---

## Проверка распределения данных по шардам

Количество документов в каждом шарде:

### shard1

```bash
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

### shard2

```bash
docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

---

## Проверка репликации

Для любого шарда:

```bash
docker compose exec -T shard1-1 mongosh --port 27018 --eval "rs.status()"
```

В статусе должно быть **3 члена replica set**.

---

## Проверка кеширования

Эндпоинт приложения:

```
http://localhost:8080/helloDoc/users
```

### Первый запрос (без кеша)

```bash
curl -w "\nTime: %{time_total}s\n" http://localhost:8080/helloDoc/users
```

Ожидаемое время:

* 300–800 ms

### Повторные запросы (из Redis)

```bash
curl -w "\nTime: %{time_total}s\n" http://localhost:8080/helloDoc/users
```

Ожидаемое время:

* **< 100 ms** (обычно 10–30 ms)

---

## Переменные окружения приложения

```env
MONGODB_URL=mongodb://mongos:27020
MONGODB_DATABASE_NAME=somedb
REDIS_URL=redis://redis:6379
```
---

## Остановка проекта

```bash
docker compose down -v
```

---

## Примечания

* Все сервисы работают в одной Docker-сети
* Кеширование реализовано на уровне приложения
* Redis используется только для read-запросов
