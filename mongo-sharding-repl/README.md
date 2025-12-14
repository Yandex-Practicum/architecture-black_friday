# MongoDB Sharding + Replication

Данный проект реализует:
- 2 шарда;
- каждый шард — Replica Set из 3 нод;
- mongos-router как единую точку входа;
- приложение подключается только к mongos.

---

## 1. Запуск проекта

```bash
docker compose up -d
```

Все контейнеры должны быть в состоянии running.

## 2. Общий шаблон выполнения команд MongoDB
```bash

docker compose exec -T <service-name> mongosh --port <port> --quiet <<EOF
<mongosh commands>
EOF
```
## 3. Инициализация Config Server Replica Set
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
## 4. Инициализация Replica Set для Shard 1
```bash

docker compose exec -T shard1-primary mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1ReplSet",
  members: [
    { _id: 0, host: "shard1-primary:27018" },
    { _id: 1, host: "shard1-secondary1:27018" },
    { _id: 2, host: "shard1-secondary2:27018" }
  ]
})
EOF
```

## 5. Инициализация Replica Set для Shard 2
```bash

docker compose exec -T shard2-primary mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard2ReplSet",
  members: [
    { _id: 0, host: "shard2-primary:27018" },
    { _id: 1, host: "shard2-secondary1:27018" },
    { _id: 2, host: "shard2-secondary2:27018" }
  ]
})
EOF
```
## 6. Добавление шардов через mongos
```bash

docker compose exec -T mongo-router mongosh --quiet <<EOF
sh.addShard("shard1ReplSet/shard1-primary:27018")
sh.addShard("shard2ReplSet/shard2-primary:27018")
EOF
```
Проверка:

```bash

docker compose exec -T mongo-router mongosh --quiet <<EOF
sh.status()
EOF
```
## 7. Проверка количества документов
Общее количество документов
```bash

docker compose exec -T mongo-router mongosh --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```
Документы на конкретном шарде
```bash

docker compose exec -T shard1-primary mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```
## 8. Проверка количества реплик
``` bash

docker compose exec -T shard1-primary mongosh --port 27018 --quiet <<EOF
rs.status().members.length
EOF
``` 
