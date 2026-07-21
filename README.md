## Инициализация репликации, шардирования и кеша

Перейдите в директорию sharding-repl-cache и запустите скрипт
```shell
cd sharding-repl-cache && ./mongo-init.sh
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

4. Кеширование:

```shell
time curl -so /dev/null http://localhost:8080/helloDoc/users
time curl -so /dev/null http://localhost:8080/helloDoc/users
```

## Остановить

```shell
docker compose down -v
```
