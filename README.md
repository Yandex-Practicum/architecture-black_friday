# «Мобильный мир» — финальная реализация: Sharding + Replication + Cache + API Gateway + Consul + CDN (схема)

## Содержимое
- **Задание 1 — Task 1
- **Задание 2 — Шардирование**: `mongo-sharding/`
- **Задание 3 — Репликация**: `mongo-sharding-repl/`
- **Задание 4 — Кеширование (Redis)**: `sharding-repl-cache/`
- **Задание 5 — Task 5
- **Задание 6 — Task 6

## Предварительные требования
- Docker 24+ и Docker Compose v2
- Свободные порты: `27017/27018/27019`, `6379`, `8080` (и те, что указаны в compose)
- ОС: Linux/macOS/WSL2 (Windows тоже ок)

---

## Быстрый старт (финальная реализация)
> Ниже — самый полный стенд (репликация + Redis + несколько инстансов `api` + API Gateway + Consul).  
> Если хотите пройтись по шагам — смотрите локальные README в папках заданий 2–4.

```bash
cd gateway-consul
# 1) Поднять контейнеры
docker compose up -d --build
docker compose ps

# 2) Инициализировать MongoDB кластер
#   2.1 Config Server RS
docker compose exec -T configsvr mongosh --port 27019 --quiet <<'EOF'
rs.initiate({
  _id: "cfgRS",
  configsvr: true,
  members: [{ _id: 0, host: "configsvr:27019" }]
})
EOF

#   2.2 Шард 1 (Replica Set из 3 нод)
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

#   2.3 Шард 2 (Replica Set из 3 нод)
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

#   2.4 Добавить шарды через mongos
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
sh.addShard("shard1RS/shard1a:27018,shard1b:27018,shard1c:27018")
sh.addShard("shard2RS/shard2a:27018,shard2b:27018,shard2c:27018")
sh.status()
EOF

#   2.5 Включить шардирование для БД и коллекции
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { userId: "hashed" })
EOF

# 3) Наполнить тестовыми данными (если < 1000)
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
if (db.helloDoc.countDocuments() < 1000) {
  const b = db.helloDoc.initializeUnorderedBulkOp();
  for (let i = 0; i < 2000; i++) b.insert({ userId: i, payload: "black_friday", createdAt: new Date() });
  b.execute();
}
db.helloDoc.countDocuments()
EOF
