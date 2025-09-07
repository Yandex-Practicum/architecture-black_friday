# Sharding + Replication + Caching (Redis) — sharding-repl-cache

## 0) Запуск
Из директории `sharding-repl-cache/`:
```bash
docker compose up -d --build
docker compose config --services
```
Ожидается:
```
api
configsvr
mongos
redis
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

## 2) Инициализация Replica Set для шардов

### Shard 1 (3 участника)
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

### Shard 2 (3 участника)
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

Проверка состава RS:
```bash
docker compose exec -T shard1a mongosh --port 27018 --quiet <<'EOF'
rs.status().members.map(m => ({name: m.name, stateStr: m.stateStr}))
EOF
docker compose exec -T shard2a mongosh --port 27018 --quiet <<'EOF'
rs.status().members.map(m => ({name: m.name, stateStr: m.stateStr}))
EOF
```

---

## 3) Подключение шардов в кластер через mongos
```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
sh.addShard("shard1RS/shard1a:27018,shard1b:27018,shard1c:27018")
sh.addShard("shard2RS/shard2a:27018,shard2b:27018,shard2c:27018")
sh.status()
EOF
```

---

## 4) Включение шардирования и коллекции
```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { userId: "hashed" })
EOF
```

---

## 5) Наполнение данными (если < 1000)
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

## 6) Проверки кластера
```bash
# общее число и распределение по шардам
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
db.helloDoc.getShardDistribution()
EOF

# число реплик в RS каждого шарда
docker compose exec -T shard1a mongosh --port 27018 --quiet <<'EOF'
rs.status().members.length
EOF
docker compose exec -T shard2a mongosh --port 27018 --quiet <<'EOF'
rs.status().members.length
EOF
```

---

## 7) Проверка приложения + кеширования
Приложение слушает на `http://localhost:8080`.

### 7.1 Базовые проверки
```bash
curl http://localhost:8080/
curl http://localhost:8080/stats
```

### 7.2 Проверка эндпоинта кеша
Эндпоинт: `/<collection_name>/users` ⇒ в нашем примере `/helloDoc/users`.

Первый запрос (cache miss, должно быть дольше):
```bash
curl -w "\nTime: %{time_total}s\n" -s http://localhost:8080/helloDoc/users -o /dev/null
```

Повторный запрос (cache hit, цель < 0.1s):
```bash
curl -w "\nTime: %{time_total}s\n" -s http://localhost:8080/helloDoc/users -o /dev/null
```

Для серии из 5 замеров:
```bash
for i in $(seq 1 5); do curl -w "Run $i -> %{time_total}s\n" -s http://localhost:8080/helloDoc/users -o /dev/null; done
```

