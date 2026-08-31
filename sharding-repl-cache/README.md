# sharding-repl-cache

## Как запустить

```sh
docker compose up 
./scripts/mongo-init.sh
```

## Проверка

Общее количество документов:

```sh
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

Количество документов шард 1:

```sh
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

Количество документов шард 2:

```sh
docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

Количество реплик шард 1:

```sh
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.status().members.length
EOF
```

Количество реплик шард 2:

```sh
docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
rs.status().members.length
EOF
```

## Проверка кеша

Первый запрос:

```sh
time curl http://localhost:8080/helloDoc/users
```

Повторный запрос:

```sh
time curl http://localhost:8080/helloDoc/users
```

## App

- http://localhost:8080
- http://localhost:8080/docs
