
# Инструкция по запуску MongoDB с репликацией и шардированием

Этот документ описывает пошаговую инициализацию окружения MongoDB с репликацией и шардированием с помощью `docker compose` и скрипта инициализации.

---

## Шаг 1. Загрузка образа MongoDB

```bash
docker pull mongo:6
```

Скачиваем официальный образ MongoDB версии 6, если он ещё не установлен.

---

## 🚀 Шаг 2. Запуск конфигурационного сервера и всех реплик шардов

```bash
docker compose up -d configsvr \
  shard1-primary shard1-secondary1 shard1-secondary2 \
  shard2-primary shard2-secondary1 shard2-secondary2
```

Запускаются:
- `configsvr` — конфигурационный сервер,
- `shard1` — реплика-сет из 3 нод,
- `shard2` — ещё один реплика-сет из 3 нод.

---

## Шаг 3. Инициализация реплика-сета конфигурационного сервера (cfgRS)

```bash
docker exec configsvr mongosh --eval '
rs.initiate({
  _id: "cfgRS",
  configsvr: true,
  members: [{ _id: 0, host: "configsvr:27017" }]
})'
```

Создаётся реплика-сет `cfgRS`, необходимая для работы `mongos`.

---

## Шаг 4. Инициализация реплика-сета `shard1RS`

```bash
docker exec shard1-primary mongosh --port 27018 --eval '
rs.initiate({
  _id: "shard1RS",
  members: [
    { _id: 0, host: "shard1-primary:27018" },
    { _id: 1, host: "shard1-secondary1:27018" },
    { _id: 2, host: "shard1-secondary2:27018" }
  ]
})'
```

Запускается реплика-сет из одной основной и двух вторичных нод для первого шарда.

---

## Шаг 5. Инициализация реплика-сета `shard2RS`

```bash
docker exec shard2-primary mongosh --port 27019 --eval '
rs.initiate({
  _id: "shard2RS",
  members: [
    { _id: 0, host: "shard2-primary:27019" },
    { _id: 1, host: "shard2-secondary1:27019" },
    { _id: 2, host: "shard2-secondary2:27019" }
  ]
})'
```

Создаётся вторая реплика-сет для второго шарда.

---

## Шаг 6. Ожидание выборов PRIMARY-ноды

```bash
sleep 10
```

Даём немного времени на выбор лидеров в реплика-сетах.

---

## Шаг 7. Запуск маршрутизатора `mongos`

```bash
docker compose up -d mongos
```

`mongos` — компонент, который маршрутизирует запросы к нужному шарду. Он требует `cfgRS` для конфигурации.

---

## Шаг 8. Подключение шардов к `mongos`

```bash
docker exec mongos mongosh --eval '
sh.addShard("shard1RS/shard1-primary:27018");
sh.addShard("shard2RS/shard2-primary:27019");
sh.status();'
```

Добавляем шардовые реплика-сеты в MongoDB через `mongos`.

---

## Шаг 9. Вставка тестовых данных

```bash
docker exec -i mongos mongosh <<EOF
use somedb
for (var i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({ age: i, name: "ly" + i });
}
EOF
```

Создаётся база `somedb` и коллекция `helloDoc`, куда вставляется 1000 документов.

---

## Шаг 10. Запуск API-сервиса

```bash
docker compose up -d pymongo_api
```

Запускается API сервис, подключённый к MongoDB через `mongos`.

---


Приложение доступно по адресу:

```
http://localhost:8080
```


---
***Для удобства тестирования я создал init скрипт по пути:***

./mongo-sharding-repl/init.sh
