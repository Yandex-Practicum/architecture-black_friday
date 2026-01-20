# MongoDB Sharding (mongo-sharding)

## Описание

Проект демонстрирует работу **шардированного кластера MongoDB** с репликацией ([второй вариант схемы](../docs/diagrams/sprint_4_task_1_v_2.drawio)):

* 1 Config Server (Replica Set)
* 2 shard'а, **каждый shard — replica set из 3 нод**
* 1 Mongos Router
* Приложение, подключающееся к MongoDB через `mongos`

---

## Архитектура

```
                        ┌────────────┐
                        │  mongos    │ 27020
                        └─────┬──────┘
                              │
        ┌─────────────────────┴─────────────────────┐
        │                                             │
┌─────────────────────┐                     ┌─────────────────────┐
│ shard1-rs           │                     │ shard2-rs           │
│  shard1-1 (27018)   │                     │  shard2-1 (27021)   │
│  shard1-2 (27018)   │                     │  shard2-2 (27021)   │
│  shard1-3 (27018)   │                     │  shard2-3 (27021)   │
└─────────────────────┘                     └─────────────────────┘

┌────────────┐
│ configSrv  │ 27017
└────────────┘
```

---

## docker-compose.yml (фрагмент с репликацией шардов)

```yaml
services:

  shard1-1:
    image: mongo:7
    command: mongod --shardsvr --replSet shard1 --port 27018 --bind_ip_all
    volumes: [shard1-1-data:/data/db]
    networks: [app-network]

  shard1-2:
    image: mongo:7
    command: mongod --shardsvr --replSet shard1 --port 27018 --bind_ip_all
    volumes: [shard1-2-data:/data/db]
    networks: [app-network]

  shard1-3:
    image: mongo:7
    command: mongod --shardsvr --replSet shard1 --port 27018 --bind_ip_all
    volumes: [shard1-3-data:/data/db]
    networks: [app-network]

  shard2-1:
    image: mongo:7
    command: mongod --shardsvr --replSet shard2 --port 27021 --bind_ip_all
    volumes: [shard2-1-data:/data/db]
    networks: [app-network]

  shard2-2:
    image: mongo:7
    command: mongod --shardsvr --replSet shard2 --port 27021 --bind_ip_all
    volumes: [shard2-2-data:/data/db]
    networks: [app-network]

  shard2-3:
    image: mongo:7
    command: mongod --shardsvr --replSet shard2 --port 27021 --bind_ip_all
    volumes: [shard2-3-data:/data/db]
    networks: [app-network]
```

---

## Инициализация Replica Set для shard'ов

### shard1

```bash
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1",
  members: [
    { _id: 0, host: "shard1-1:27018" },
    { _id: 1, host: "shard1-2:27018" },
    { _id: 2, host: "shard1-3:27018" }
  ]
})
EOF
```

### shard2

```bash
docker compose exec -T shard2-1 mongosh --port 27021 --quiet <<EOF
rs.initiate({
  _id: "shard2",
  members: [
    { _id: 0, host: "shard2-1:27021" },
    { _id: 1, host: "shard2-2:27021" },
    { _id: 2, host: "shard2-3:27021" }
  ]
})
EOF
```

---

## Добавление shard'ов в кластер

```bash
docker compose exec -T mongos mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1/shard1-1:27018,shard1-2:27018,shard1-3:27018")
sh.addShard("shard2/shard2-1:27021,shard2-2:27021,shard2-3:27021")
EOF
```

---

## Проверка состояния

```bash
docker compose exec -T mongos mongosh --port 27020 --quiet <<EOF
sh.status()
EOF
```

Ожидаемый результат:

* Каждый shard имеет 3 replica set member
* Один PRIMARY, два SECONDARY

---

## Примечания

* Все записи выполняются через `mongos`
* Репликация повышает отказоустойчивость
* Конфигурация соответствует требованиям задания
