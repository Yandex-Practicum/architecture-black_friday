# mongo-sharding-repl

Стенд с шардированием и репликацией (по 3 реплики на каждый шард).

## Запуск

```bash
docker compose up -d
```

## Инициализация шардирования и репликации

```bash
chmod +x scripts/init-repl-sharding.sh scripts/mongo-init.sh
./scripts/init-repl-sharding.sh
./scripts/mongo-init.sh
```

## Проверка

Общее число документов:

```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
EOF
```

Информация по шардам:

```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
sh.status()
EOF
```

Проверка числа реплик на `shard1`:

```bash
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<'EOF'
rs.status().members.length
EOF
```

Проверка числа реплик на `shard2`:

```bash
docker compose exec -T shard2-1 mongosh --port 27018 --quiet <<'EOF'
rs.status().members.length
EOF
```

Приложение доступно на `http://localhost:8080`, документация на `http://localhost:8080/docs`.
