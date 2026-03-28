# MongoDB Sharding + Replication + Caching

## Описание проекта

Проект демонстрирует работу MongoDB с **шардированием, репликацией и
кешированием**.

Архитектура кластера:

-   **Config Server** --- хранит метаданные кластера
-   **mongos_router** --- маршрутизатор запросов
-   **Shard1 (ReplicaSet)** --- `shard1-1`, `shard1-2`, `shard1-3`
-   **Shard2 (ReplicaSet)** --- `shard2-1`, `shard2-2`, `shard2-3`
-   **redis** --- кеш для ускорения повторных запросов
-   **pymongo-api** --- приложение, работающее через `mongos_router` и
    `redis`

Реализовано:

-   шардирование данных между двумя шардами
-   репликация внутри каждого шарда
-   кеширование эндпоинта `/{collection_name}/users` через Redis

Схема представлена на вкладке **"3_плюс кеширование"**
в файле\
[task1.drawio](./task1.drawio)

---

# Запуск проекта

Перейти в директорию проекта:

``` bash
cd sharding-repl-cache
```

Запустить контейнеры:

``` bash
docker compose up -d
```

Проверить состояние контейнеров:

``` bash
docker compose ps
```

---

# Настройка Config Server

``` bash
docker compose exec configSrv mongosh --port 27017
```

``` javascript
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv:27017" }
  ]
})
```

Проверка:

``` javascript
rs.status()
exit
```

---

# Настройка ReplicaSet shard1

``` bash
docker compose exec shard1-1 mongosh --port 27017
```

``` javascript
rs.initiate({
  _id: "shard1ReplSet",
  members: [
    { _id: 0, host: "shard1-1:27017" },
    { _id: 1, host: "shard1-2:27017" },
    { _id: 2, host: "shard1-3:27017" }
  ]
})
```

Проверка:

``` javascript
rs.status()
exit
```

---

# Настройка ReplicaSet shard2

``` bash
docker compose exec shard2-1 mongosh --port 27017
```

``` javascript
rs.initiate({
  _id: "shard2ReplSet",
  members: [
    { _id: 0, host: "shard2-1:27017" },
    { _id: 1, host: "shard2-2:27017" },
    { _id: 2, host: "shard2-3:27017" }
  ]
})
```

Проверка:

``` javascript
rs.status()
exit
```

---

# Подключение шардов к mongos

``` bash
docker compose exec mongos_router mongosh --port 27017
```

``` javascript
sh.addShard("shard1ReplSet/shard1-1:27017,shard1-2:27017,shard1-3:27017")
sh.addShard("shard2ReplSet/shard2-1:27017,shard2-2:27017,shard2-3:27017")
```

Проверка:

``` javascript
sh.status()
```

---
# Включение шардирования

``` javascript
use somedb
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { age: 1 })
```

---

# Добавление тестовых данных

``` javascript
for (let i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({
    name: "user_" + i,
    age: Math.floor(Math.random() * 50) + 20
  })
}
```

Проверка:

``` javascript
db.helloDoc.countDocuments()
```

Должно быть не менее **1000 документов**.

---

# Распределение данных между шардами

``` javascript
sh.splitAt("somedb.helloDoc", { age: 500 })
sh.moveChunk("somedb.helloDoc", { age: 100 }, "shard1ReplSet")
```

Проверка:

``` javascript
db.helloDoc.getShardDistribution()
```

---

# Проверка репликации

``` bash
docker compose exec shard1-1 mongosh --eval "rs.status()"
docker compose exec shard2-1 mongosh --eval "rs.status()"
```

В каждом ReplicaSet должно быть:

-   1 PRIMARY
-   2 SECONDARY

---

# Проверка работы приложения

Открыть в браузере:

http://localhost:8080/

Swagger:

http://localhost:8080/docs

На главной странице должно отображаться:

-   `mongo_topology_type: Sharded`
-   `cache_enabled: true`
-   общее количество документов ≥ 1000
-   список шардов

---

# Проверка кеширования

Кеширование работает для эндпоинта:

/helloDoc/users

Проверка времени ответа:

``` bash
curl -o /dev/null -s -w 'time_total=%{time_total}\n' http://localhost:8080/helloDoc/users
curl -o /dev/null -s -w 'time_total=%{time_total}\n' http://localhost:8080/helloDoc/users
```

Ожидаемый результат:

-   первый запрос выполняется медленно (запрос в MongoDB)
-   второй и последующие запросы выполняются быстрее за счёт Redis
-   время повторного запроса **менее 100 мс**

---

# Остановка проекта

``` bash
docker compose down
```
