# mongo-sharding

Стенд с MongoDB шардированием на 2 шарда.

## Запуск

```bash
docker compose up -d
```

## Инициализация кластера

```bash
chmod +x scripts/init-sharding.sh scripts/mongo-init.sh
./scripts/init-sharding.sh
./scripts/mongo-init.sh
```

## Проверка

Проверить общее число документов:

```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
EOF
```

Проверить распределение по шардам:

```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
db.helloDoc.getShardDistribution()
EOF
```

Приложение доступно на `http://localhost:8080`, документация на `http://localhost:8080/docs`.
