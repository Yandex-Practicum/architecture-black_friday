В этом задании речь идет о конфигурации с одним монго-раутером, одним конфиг-сервером и двумя монго-шардами

Из инструкций ниже сгенерирован скрипт init-cluster.sh с помощью ИИ со всеми командами, чтобы сервисы друг друга ждали и не падали, который останавливает и убирает все контейнеры сохраняя данные

Ввиду того что задания похожи, в ямлах не даю имена контейнерам чтобы докер дал имена как производное от имени проекта

## Запуск
**1. Eсли бежал другой проект, убираем старые записи.**
docker compose down -v 2>/dev/null || true


**2. Запустить все узлы кроме роутера:**
2. Запускаем не все сервисы сразу: сервису роутера mongos нужно дождаться пока все инициализируется
docker compose up -d configsvr shard1 shard2


**3. Инициировать конфиг-сервер: у него нет реплик по этой схеме поэтому в мемберз только один**

docker compose exec -T configsvr mongosh --quiet <<'EOF'
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [
    { _id: 0, host: "configsvr:27017" }
  ]
})
EOF



**4. Инициируем реплики-сеты. Здесь в каждой реплика-сете у нас пока по одному инстансу (ноде, узлу), тоже один мембер**

docker compose exec -T shard1 mongosh --quiet <<'EOF'
rs.initiate({
  _id: "shard1ReplSet",
  members: [
    { _id: 0, host: "shard1:27017" }
  ]
})
EOF

docker compose exec -T shard2 mongosh --quiet <<'EOF'
rs.initiate({
  _id: "shard2ReplSet",
  members: [
    { _id: 0, host: "shard2:27017" }
  ]
})
EOF

**5. Подождать несколько секунд чтобы все инициализировалось и запустить раутер.**

docker compose up -d mongos

**6. Добавить шарды:**

docker compose exec -T mongos mongosh --quiet <<'EOF'
sh.addShard("shard1ReplSet/shard1:27017")
sh.addShard("shard2ReplSet/shard2:27017")
sh.status()
EOF


**7. Cоздаем бд и коллекцию**
docker compose exec -T mongos mongosh --quiet <<'EOF'
sh.enableSharding("somedb", "shard1ReplSet")

const database = db.getSiblingDB("somedb")

database.createCollection("helloDoc")
database.helloDoc.createIndex({ age: 1 })

sh.shardCollection(
  "somedb.helloDoc",
  { age: 1 }
)

sh.splitAt(
  "somedb.helloDoc",
  { age: 500 }
)

sh.moveChunk(
  "somedb.helloDoc",
  { age: 750 },
  "shard2ReplSet"
)
EOF


**8. Заполняем данными**
docker compose exec -T mongos mongosh --quiet <<'EOF'
const database = db.getSiblingDB("somedb")
const documents = []

for (let i = 0; i < 1000; i++) {
  documents.push({
    age: i,
    name: "ly" + i
  })
}

database.helloDoc.insertMany(documents)

print("Total documents:")
print(database.helloDoc.countDocuments({}))
EOF


**9. Проверка:**
docker compose exec -T mongos mongosh --quiet <<'EOF'
const database = db.getSiblingDB("somedb")

print("Total:")
print(database.helloDoc.countDocuments({}))

print("Per shard:")

database.helloDoc.aggregate([
  {
    $collStats: {
      count: {}
    }
  },
  {
    $project: {
      _id: 0,
      shard: 1,
      count: 1
    }
  },
  {
    $sort: {
      shard: 1
    }
  }
]).forEach(printjson)
EOF



Приложение должно подключаться к mongodb://mongos:27017
В ямл добавлен сервис приложения