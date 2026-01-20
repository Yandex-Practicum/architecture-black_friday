# Задача 2. MongoDB Sharding (mongo-sharding)

## Описание

Проект демонстрирует работу **шардированного кластера MongoDB** ([первый вариант схемы](../docs/diagrams/sprint_4_task_1_v_1.drawio)):

* 1 Config Server (Replica Set)
* 2 Shard'а
* 1 Mongos Router
* Приложение, подключающееся к MongoDB через `mongos`

Кластер разворачивается с помощью **Docker Compose**.

---

## Архитектура

```
                ┌────────────┐
                │  mongos    │ 27020
                └─────┬──────┘
                      │
      ┌───────────────┴───────────────┐
      │                               │
┌────────────┐                 ┌────────────┐
│  shard1    │ 27018           │  shard2    │ 27019
└────────────┘                 └────────────┘

┌────────────┐
│ configSrv  │ 27017
└────────────┘
```

---

## Требования

* Docker
* Docker Compose (v2)

Проверить установку:

```bash
docker --version
docker compose version
```

---

## Запуск проекта

Перейдите в директорию проекта и выполните:

```bash
docker compose up -d
```

Проверьте, что все контейнеры запущены и имеют статус `healthy`:

```bash
docker ps
```

Ожидаемый результат:

* configSrv — healthy
* shard1 — healthy
* shard2 — healthy
* mongos — healthy

---

## Инициализация шардирования

Для инициализации БД и наполнения данными используется shell-скрипт.

### 1. Скрипт инициализации

Файл `init-sharding.sh`:

```bash
#!/bin/bash
set -e

docker compose exec -T mongos mongosh --port 27020 --quiet <<EOF
use somedb

sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { _id: "hashed" })

for (let i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({ age: i, name: "ly" + i })
}

print("TOTAL DOCUMENTS:")
db.helloDoc.countDocuments()
EOF

# Проверка shard1
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

# Проверка shard2
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

Сделайте файл исполняемым:

```bash
chmod +x init-sharding.sh
```

### 2. Выполнение скрипта

```bash
./init-sharding.sh
```

---

## Проверка распределения данных

### Общее количество документов (через mongos)

```bash
docker compose exec -T mongos mongosh --port 27020 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

### Количество документов на shard1

```bash
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

### Количество документов на shard2

```bash
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

Ожидаемый результат:

* Общее количество документов ≥ 1000
* Документы распределены между shard1 и shard2

---

## Используемые значения по заданию

* Имя проекта: `mongo-sharding`
* База данных: `somedb`
* Коллекция: `helloDoc`

---

## Остановка и очистка

```bash
docker compose down -v
```

---

## Примечания

* Все операции записи выполняются через `mongos`, как требуется для шардированного кластера
* Для равномерного распределения используется `hashed` шард-ключ
