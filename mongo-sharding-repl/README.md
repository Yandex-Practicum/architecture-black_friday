# MongoDB Sharding + Replication

## Описание проекта

Проект демонстрирует работу **MongoDB Sharding с репликацией**.

Архитектура кластера:

- **Config Server** – хранит метаданные кластера
- **mongos_router** – маршрутизатор запросов
- **Shard1 (ReplicaSet)**  
  - shard1-1 (PRIMARY)
  - shard1-2 (SECONDARY)
  - shard1-3 (SECONDARY)

- **Shard2 (ReplicaSet)**  
  - shard2-1 (PRIMARY)
  - shard2-2 (SECONDARY)
  - shard2-3 (SECONDARY)

- **pymongo-api** – приложение, работающее через `mongos_router`

Таким образом:

- каждый шард является **ReplicaSet из 3 узлов**
- данные распределяются между шардами
- репликация обеспечивает отказоустойчивость

Схема представлена на вкладке **"2_плюс репликация для каждого шарда** в файле [task1.drawio](./task1.drawio).
---

# Запуск проекта

Перейти в директорию проекта:

```bash
cd mongo-sharding-repl
```
#  Запустить контейнеры:
```bash
docker compose up -d
```
# Проверить состояние контейнеров:
```bash
docker compose ps
```
---
# Настройка ReplicaSet для Config Server

Подключиться к контейнеру:

```bash
docker exec -it configSrv mongosh
```
Инициализировать ReplicaSet:

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
```bash
rs.status()
```

Выйти из shell:
```bash
exit
```
---
# Настройка ReplicaSet для shard1

Подключиться:

```bash
docker exec -it shard1-1 mongosh
```

Инициализация:

```javascript
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

```javascript
rs.status()
```

Выйти:

```javascript
exit
```

---

# Настройка ReplicaSet для shard2

Подключиться:

```bash
docker exec -it shard2-1 mongosh
```

Инициализация:

```javascript
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

```javascript
rs.status()
```

Выйти:

```javascript
exit
```

---

# Подключение шардов к mongos

Подключиться к роутеру:

```bash
docker exec -it mongos_router mongosh
```

Добавить шарды:

```javascript
sh.addShard("shard1ReplSet/shard1-1:27017,shard1-2:27017,shard1-3:27017")
```

```javascript
sh.addShard("shard2ReplSet/shard2-1:27017,shard2-2:27017,shard2-3:27017")
```

Проверка:

```javascript
sh.status()
```

---

# Включение шардирования

Используем базу:

```javascript
use somedb
```

Включаем sharding:

```javascript
sh.enableSharding("somedb")
```

Шардируем коллекцию:

```javascript
sh.shardCollection("somedb.helloDoc", { age: 1 })
```

---

# Добавление тестовых данных

Добавим 1000 документов:

```javascript
for (let i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({ age: i, name: "ly" + i })
}
```

---

# Распределение данных между шардами

Разделим коллекцию:

```javascript
sh.splitAt("somedb.helloDoc", { age: 500 })
```

Переместим один chunk:

```javascript
sh.moveChunk("somedb.helloDoc", { age: 100 }, "shard1ReplSet")
```

---

# Проверка работы кластера

Общее количество документов:

```javascript
db.helloDoc.countDocuments()
```

Ожидаемый результат:

```
1000
```

Распределение данных по шардам:

```javascript
db.helloDoc.getShardDistribution()
```

Ожидаемый результат:

- часть документов на `shard1`
- часть документов на `shard2`

Проверка состояния шардов:

```javascript
sh.status()
```

---

# Проверка репликации

Проверка shard1:

```bash
docker exec -it shard1-1 mongosh --eval "rs.status()"
```

Проверка shard2:

```bash
docker exec -it shard2-1 mongosh --eval "rs.status()"
```

В каждом ReplicaSet должно быть:

- 1 PRIMARY
- 2 SECONDARY

---

# Проверка приложения

## Если вы запускаете проект на локальной машине

Откройте в браузере:

http://localhost:8080

Приложение должно показать:

- общее количество документов
- количество документов на каждом шарде
- количество реплик


---

# Остановка проекта

```bash
docker compose down
```