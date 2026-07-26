# MongoDB sharding

Проект запускает `pymongo-api`, один `mongos`, один config server и два шарда MongoDB.

## Запуск и инициализация

```sh
docker compose up -d --build
./scripts/mongo-init.sh
```

Скрипт инициализирует config server и оба шарда, добавляет шарды в кластер,
включает шардирование `somedb.helloDoc` по хешированному ключу `name` и создаёт
1000 документов.

## Проверка

```sh
docker compose ps
curl --silent http://localhost:8080
curl --silent http://localhost:8080/helloDoc/count
```

Количество документов на первом шарде:

```sh
docker compose exec -T shard1 mongosh --port 27018 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
EOF
```

Количество документов на втором шарде:

```sh
docker compose exec -T shard2 mongosh --port 27019 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
EOF
```

## Остановка

```sh
docker compose down
```

Чтобы полностью удалить данные и повторить инициализацию:

```sh
docker compose down -v
```
