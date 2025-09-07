# Mongo Sharding — запуск и инициализация

## 1. Запуск проекта
Поднимите все сервисы (MongoDB + API):

```bash
docker compose up -d --build
```

Проверить список сервисов:
```bash
docker compose config --services
```

Ожидается:
```
api
configsvr
mongos
shard1
shard2
```

---

## 2. Инициализация Config Server RS
Config Server всегда должен быть replica set:

```bash
docker compose exec -T configsvr mongosh --port 27019 --quiet <<'EOF'
rs.initiate({
  _id: "cfgRS",
  configsvr: true,
  members: [{ _id: 0, host: "configsvr:27019" }]
})
EOF
```

---

## 3. Инициализация шардов
### Shard1 RS
```bash
docker compose exec -T shard1 mongosh --port 27018 --quiet <<'EOF'
rs.initiate({
  _id: "shard1RS",
  members: [{ _id: 0, host: "shard1:27018" }]
})
EOF
```

### Shard2 RS
```bash
docker compose exec -T shard2 mongosh --port 27018 --quiet <<'EOF'
rs.initiate({
  _id: "shard2RS",
  members: [{ _id: 0, host: "shard2:27018" }]
})
EOF
```

---

## 4. Подключение шардов к кластеру через mongos
```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
sh.addShard("shard1RS/shard1:27018")
sh.addShard("shard2RS/shard2:27018")
sh.status()
EOF
```

---

## 5. Включение шардирования базы и коллекции
```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { userId: "hashed" })
EOF
```

---

## 6. Заполнение коллекции тестовыми данными
```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
if (db.helloDoc.countDocuments() < 1000) {
  const b = db.helloDoc.initializeUnorderedBulkOp();
  for (let i = 0; i < 2000; i++) {
    b.insert({ userId: i, payload: "black_friday", createdAt: new Date() });
  }
  b.execute();
}
db.helloDoc.countDocuments()
EOF
```

---

## 7. Проверка распределения по шардам
```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
db.helloDoc.getShardDistribution()
EOF
```

---

## 8. Проверка работы приложения
Приложение доступно по адресу [http://localhost:8080](http://localhost:8080).

Проверить доступность:
```bash
curl http://localhost:8080/
```

