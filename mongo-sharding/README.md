# MongoDB Sharding — Initialization Guide

Данный проект реализует базовый sharded-cluster MongoDB (2 шарда, без репликации и кеширования).
Взаимодействие приложения с базой данных осуществляется **исключительно через mongos-router**.

---

## 1. Запуск инфраструктуры

```bash
docker compose up -d
```
Убедитесь, что все сервисы перешли в состояние running.

## 2. Общий шаблон выполнения команд MongoDB
Для автоматизации инициализации и проверки состояния MongoDB используется следующий шаблон shell-команды:

```bash

docker compose exec -T <service-name> mongosh --port <mongo-port> --quiet <<EOF
<mongosh commands here>
EOF
```
Данный подход позволяет:

- выполнять команды без интерактивной сессии;

- использовать их в CI/CD или скриптах инициализации;

- воспроизводить настройку кластера.

## 3. Инициализация Config Server Replica Set

Config Server обязан работать в режиме replica set, даже если состоит из одной ноды.

```bash

docker compose exec -T mongo-config mongosh --port 27019 --quiet <<EOF
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [
    { _id: 0, host: "mongo-config:27019" }
  ]
})
EOF
```

Проверка статуса:

```bash

docker compose exec -T mongo-config mongosh --port 27019 --quiet <<EOF
rs.status()
EOF
```

## 4. Добавление шардов через mongos
Подключение выполняется через router, а не напрямую к шардам.

```bash

docker compose exec -T mongo-router mongosh --quiet <<EOF
sh.addShard("mongo-shard1:27018")
sh.addShard("mongo-shard2:27018")
EOF
```

Проверка состояния кластера:

```bash

docker compose exec -T mongo-router mongosh --quiet <<EOF
sh.status()
EOF
```
## 5. Включение шардирования базы данных
```bash

docker compose exec -T mongo-router mongosh --quiet <<EOF
sh.enableSharding("somedb")
EOF
```
## 6. Включение шардирования коллекции
Пример — коллекция orders, ключ шардирования userId (hashed):

```bash

docker compose exec -T mongo-router mongosh --quiet <<EOF
sh.shardCollection(
  "somedb.orders",
  { userId: "hashed" }
)
EOF
```
###7. Проверка данных на конкретном шарде
Пример подсчёта документов в коллекции helloDoc базы somedb
на инстансе Shard 1:

``` bash

docker compose exec -T mongo-shard1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```
Аналогично можно выполнять проверки для второго шарда (mongo-shard2).
___


Архитектурные ограничения текущего этапа
На данном этапе реализовано:

✔ горизонтальное масштабирование (sharding);

✘ отказоустойчивость (нет репликации);

✘ кеширование запросов.