
# Установка MongoDB с шардированием и API

Этот документ описывает пошаговую инициализацию окружения MongoDB с шардированием и запуском API-сервиса с помощью Docker Compose.

---

## Шаг 1. Загрузка Docker-образов

```bash
docker pull mongo:6
```

Скачиваем официальный образ MongoDB, если он ещё не установлен локально.

---

## Шаг 2. Запуск `configsvr`, `shard1`, `shard2`

```bash
docker compose up -d configsvr shard1 shard2
```

Запускаются три ключевых компонента MongoDB-шардирования:
- `configsvr` — конфигурационный сервер.
- `shard1` — первый шард.
- `shard2` — второй шард.

---

## Шаг 3. Инициализация Replica Set для `configsvr`

```bash
docker exec configsvr mongosh --eval '
rs.initiate({
  _id: "cfgRS",
  configsvr: true,
  members: [{ _id: 0, host: "configsvr:27017" }]
})'
```

MongoDB требует, чтобы все узлы были частью реплика-сетов. Этот шаг инициализирует реплика-сет `cfgRS` для `configsvr`.

---

## Шаг 4. Инициализация Replica Set для `shard1`

```bash
docker exec shard1 mongosh --port 27018 --eval '
rs.initiate({
  _id: "shard1RS",
  members: [{ _id: 0, host: "shard1:27018" }]
})'
```

Создаём реплика-сет `shard1RS` для первого шарда.

---

## Шаг 5. Инициализация Replica Set для `shard2`

```bash
docker exec shard2 mongosh --port 27019 --eval '
rs.initiate({
  _id: "shard2RS",
  members: [{ _id: 0, host: "shard2:27019" }]
})'
```

Создаём реплика-сет `shard2RS` для второго шарда.

---

## Шаг 6. Запуск `mongos` (маршрутизатора)

```bash
docker exec -i mongos mongosh <<EOF
use somedb
for (var i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({ age: i, name: "ly" + i });
}
EOF
```

Запускаем `mongos` — компонент MongoDB.

---

## Шаг 7. Добавление шардов в `mongos`

```bash
docker exec mongos mongosh --eval '
sh.addShard("shard1RS/shard1:27018");
sh.addShard("shard2RS/shard2:27019");
sh.status();'
```

Подключаем оба шарда к маршрутизатору `mongos`, после чего MongoDB будет понимать, как распределять данные между ними.

---

## Шаг 8. Добавление данных

```bash
docker exec -i mongos mongosh <<EOF
use somedb
for (var i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({ age: i, name: "ly" + i });
}
EOF
```

Добавление коллекции и данных для тестирования.

---

## Шаг 9. Запуск API-сервиса

```bash
docker compose up -d pymongo_api
```

Запускается  API-сервис, который подключается к `mongos` и работает с MongoDB-шардированием.

---

## 🎉 Результат

Окружение готово. Можно обращаться к API по адресу:

```
http://localhost:8080
```

---
***Для удобства тестирования я создал init скрипт по пути:***

./mongo-sharding/init.sh
