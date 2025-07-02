# 📦 Инструкция по запуску MongoDB с репликацией, шардированием и кешированием

Этот документ описывает пошаговую инициализацию окружения MongoDB с репликацией, шардированием и поддержкой Redis-кеша с помощью `docker compose` и bash-скрипта инициализации.

---

## Шаг 1. Загрузка Docker-образов

```bash
docker pull mongo:6
docker pull redis:7
```

Скачиваем образы MongoDB и Redis.

---

## Шаг 2. Запуск конфигурационного сервера и всех реплик шардов

```bash
docker compose up -d configsvr \
  shard1-primary shard1-secondary1 shard1-secondary2 \
  shard2-primary shard2-secondary1 shard2-secondary2
```

Запускаются:
- `configsvr` — конфигурационный сервер,
- `shard1` и `shard2` — реплика-сеты по 3 узла.

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

---

## Шаг 4. Инициализация Replica Set для `shard1`

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

---

## Шаг 5.Инициализация Replica Set для `shard2`

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

---

## Шаг 6. Ожидание выборов PRIMARY-ноды

```bash
sleep 10
```

MongoDB должен выбрать PRIMARY в каждом реплика-сете.

---

## Шаг 7. Запуск маршрутизатора `mongos`

```bash
docker compose up -d mongos
```

---

## Шаг 8. Подключение шардов к `mongos`

```bash
docker exec mongos mongosh --eval '
sh.addShard("shard1RS/shard1-primary:27018");
sh.addShard("shard2RS/shard2-primary:27019");
sh.status();'
```

---

## Шаг 9. Добавление шардов в `mongos`

```bash
docker exec -i mongos mongosh <<EOF
use somedb
for (var i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({ age: i, name: "ly" + i });
}
EOF
```

---

## Шаг 10. Запуск Redis и API-сервиса

```bash
docker compose up -d redis pymongo_api
```

- `redis` — кеш для API
- `pymongo_api` — веб-приложение на FastAPI, подключённое к `mongos`

---

## Проверка кеширования

Повторный вызов эндпоинта:

```bash
curl http://localhost:8080/helloDoc/users
```

выполнится значительно быстрее за счёт Redis-кеша. Первый вызов будет медленнее (около 1 секунды).

---

## Адрес приложения

Окружение готово. Можно обращаться к API по адресу:

```
http://localhost:8080
```

--
***Для удобства тестирования я создал init скрипт по пути:***

mongo-sharding-repl-cache/init.sh
