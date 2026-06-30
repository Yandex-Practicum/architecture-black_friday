# Шардирование MongoDB с репликами и Redis-кешем (Схема 3)

Конфигурация: один mongos-роутер, конфиг-сервер с тремя репликами, два шарда каждый с тремя репликами, Redis для кеширования.


## Кеширование

Приложение кеширует ответы эндпоинта `/<collection_name>/users` в Redis.
При первом запросе данные берутся из MongoDB и сохраняются в Redis.
При повторном запросе данные отдаются из кеша — заметно быстрее.

Переменная окружения для включения кеша:
```
REDIS_URL: "redis://redis:6379"
```

---

## Запуск

**1. Eсли бежал другой проект, убираем старые записи.**
docker compose down -v 2>/dev/null || true


**2. Запустить все узлы кроме роутера:**

docker compose up -d configsvr configsvr1 configsvr2 shard1 shard1_1 shard1_2 shard2 shard2_1 shard2_2 redis


**3. Инициировать конфиг-сервер (3 члена реплика-сета):**

docker compose exec -T configsvr mongosh --quiet <<'EOF'
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [
    { _id: 0, host: "configsvr:27017" },
    { _id: 1, host: "configsvr1:27017" },
    { _id: 2, host: "configsvr2:27017" }
  ]
})
EOF


**4. Подождать ~5 секунд, затем инициировать реплика-сеты шардов:**

Шард 1:

docker compose exec -T shard1 mongosh --quiet <<'EOF'
rs.initiate({
  _id: "shard1ReplSet",
  members: [
    { _id: 0, host: "shard1:27017" },
    { _id: 1, host: "shard1_1:27017" },
    { _id: 2, host: "shard1_2:27017" }
  ]
})
EOF


Шард 2:

docker compose exec -T shard2 mongosh --quiet <<'EOF'
rs.initiate({
  _id: "shard2ReplSet",
  members: [
    { _id: 0, host: "shard2:27017" },
    { _id: 1, host: "shard2_1:27017" },
    { _id: 2, host: "shard2_2:27017" }
  ]
})
EOF


**5. Подождать ~5 секунд и запустить роутер и приложение:**

docker compose up -d mongos pymongo_api


**6. Добавить шарды:**

docker compose exec -T mongos mongosh --quiet <<'EOF'
sh.addShard("shard1ReplSet/shard1:27017,shard1_1:27017,shard1_2:27017")
sh.addShard("shard2ReplSet/shard2:27017,shard2_1:27017,shard2_2:27017")
sh.status()
EOF


**7. Создать БД и коллекцию:**

docker compose exec -T mongos mongosh --quiet <<'EOF'
sh.enableSharding("somedb", "shard1ReplSet")

const database = db.getSiblingDB("somedb")

database.createCollection("helloDoc")
database.helloDoc.createIndex({ age: 1 })

sh.shardCollection("somedb.helloDoc", { age: 1 })
sh.splitAt("somedb.helloDoc", { age: 500 })
sh.moveChunk("somedb.helloDoc", { age: 750 }, "shard2ReplSet")
EOF


**8. Заполнить данными:**

docker compose exec -T mongos mongosh --quiet <<'EOF'
const database = db.getSiblingDB("somedb")
const documents = []

for (let i = 0; i < 1000; i++) {
  documents.push({ age: i, name: "ly" + i })
}

database.helloDoc.insertMany(documents)

print("Total documents:")
print(database.helloDoc.countDocuments({}))
EOF


**9. Проверка распределения по шардам:**

docker compose exec -T mongos mongosh --quiet <<'EOF'
const database = db.getSiblingDB("somedb")

print("Total:")
print(database.helloDoc.countDocuments({}))

print("Per shard:")
database.helloDoc.aggregate([
  { $collStats: { count: {} } },
  { $project: { _id: 0, shard: 1, count: 1 } },
  { $sort: { shard: 1 } }
]).forEach(printjson)
EOF




Приложение подключается к mongodb://mongos:27017 и redis://redis:6379.