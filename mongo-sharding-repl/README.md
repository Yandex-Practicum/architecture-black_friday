## Инициализация репликации и шардирования

Запустите скрипт, он делает то же самое, что и README.md из mongo-sharding
```shell
./mongo-init.sh
```

## Как проверить

1. Откройте http://localhost:8080

2. Состав реплика-сета каждого шарда:

```shell
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<'EOF'
rs.status().members.map(m => ({ name: m.name, state: m.stateStr }))
EOF
```

```shell
docker compose exec -T shard2-1 mongosh --port 27018 --quiet <<'EOF'
rs.status().members.map(m => ({ name: m.name, state: m.stateStr }))
EOF
```

3. Количество документов на каждом шарде:

```shell
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
EOF
```

```shell
docker compose exec -T shard2-1 mongosh --port 27018 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
EOF
```

## Остановить

```shell
docker compose down -v
```
