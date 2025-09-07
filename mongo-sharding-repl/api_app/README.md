## 0) Запуск
```bash
docker compose up -d --build
docker compose config --services
```
Ожидается:
```
api
configsvr
mongos
shard1a
shard1b
shard1c
shard2a
shard2b
shard2c
```

---

## 1) Инициализация Config Server RS
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

## 2) Инициализация Replica Set для Shard 1 (3 члена)
Запускаем rs на любом из членов (например, shard1a):
```bash
docker compose exec -T shard1a mongosh --port 27018 --quiet <<'EOF'
rs.initiate({
  _id: "shard1RS",
  members: [
    { _id: 0, host: "shard1a:27018", priority: 2 },
    { _id: 1, host: "shard1b:27018", priority: 1 },
    { _id: 2, host: "shard1c:27018", priority: 1 }
  ]
})
EOF
```

Проверка:
```bash
docker compose exec -T shard1a mongosh --port 27018 --quiet <<'EOF'
rs.status().members.map(m => ({name: m.name, stateStr: m.stateStr, prio: m.priority}))
EOF
```

---

## 3) Инициализация Replica Set для Shard 2 (3 члена)
```bash
docker compose exec -T shard2a mongosh --port 27018 --quiet <<'EOF'
rs.initiate({
  _id: "shard2RS",
  members: [
    { _id: 0, host: "shard2a:27018", priority: 2 },
    { _id: 1, host: "shard2b:27018", priority: 1 },
    { _id: 2, host: "shard2c:27018", priority: 1 }
  ]
})
EOF
```

Проверка:
```bash
docker compose exec -T shard2a mongosh --port 27018 --quiet <<'EOF'
rs.status().members.map(m => ({name: m.name, stateStr: m.stateStr, prio: m.priority}))
EOF
```

---

## 4) Подключение шардов к кластеру через mongos
Важно: используем формат `"rsName/host1,host2,host3"`.

```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
sh.addShard("shard1RS/shard1a:27018,shard1b:27018,shard1c:27018")
sh.addShard("shard2RS/shard2a:27018,shard2b:27018,shard2c:27018")
sh.status()
EOF
```

---

## 5) Включение шардирования базы и коллекции
```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { userId: "hashed" })
EOF
```

---

## 6) Наполнение тестовыми данными (если < 1000)
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

## 7) Проверки

### 7.1 Общее количество документов и распределение по шардам
```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
db.helloDoc.getShardDistribution()
EOF
```

### 7.2 Количество реплик в каждом шарде
```bash
# Shard1
docker compose exec -T shard1a mongosh --port 27018 --quiet <<'EOF'
rs.status().members.length
EOF

# Shard2
docker compose exec -T shard2a mongosh --port 27018 --quiet <<'EOF'
rs.status().members.length
EOF
```

Ожидается по **3** участника в каждом Replica Set.

---

## 8) Проверка приложения
Приложение доступно на http://localhost:8080

```bash
curl http://localhost:8080/
curl http://localhost:8080/stats
```