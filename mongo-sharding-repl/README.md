# MongoDB sharding with replication

Проект содержит `pymongo-api`, `mongos`, config server и два шарда. Каждый шард — replica set из трёх MongoDB-инстансов:

- `shard1-rs`: `shard1-1`, `shard1-2`, `shard1-3`;
- `shard2-rs`: `shard2-1`, `shard2-2`, `shard2-3`.

База данных называется `somedb`, коллекция — `helloDoc`, hashed-ключ шардирования — поле `name`.

## Запуск и настройка

Из директории `mongo-sharding-repl` выполните:

```sh
docker compose up -d --build
chmod +x init-sharding.sh
./init-sharding.sh
```

`init-sharding.sh` ожидает готовности всех узлов, создаёт replica set для каждого шарда, ждёт три healthy-реплики, регистрирует шарды в `mongos`, включает шардирование и записывает 1000 документов. Повторный запуск безопасен: конфигурация replica set сохраняется, а тестовые документы пересоздаются.

Скрипт автоматически выбирает доступную команду `docker compose` или `docker-compose`.

## Проверка данных и шардов

Общее количество и распределение документов:

```sh
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
db.helloDoc.getShardDistribution()
EOF
```

Количество документов на каждом шарде следует проверять через primary соответствующего replica set:

```sh
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
EOF

docker compose exec -T shard2-1 mongosh --port 27018 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
EOF
```

Сумма значений на `shard1-rs` и `shard2-rs` должна быть равна общему количеству через `mongos` и быть не меньше 1000.

## Проверка репликации

```sh
docker compose exec -T shard1-1 mongosh --port 27018 --quiet \
  --eval 'rs.status().members.map(({name, stateStr, health}) => ({name, stateStr, health}))'

docker compose exec -T shard2-1 mongosh --port 27018 --quiet \
  --eval 'rs.status().members.map(({name, stateStr, health}) => ({name, stateStr, health}))'
```

В каждом результате должно быть три узла: один `PRIMARY`, два `SECONDARY`, у всех `health: 1`.

## Проверка приложения

```sh
curl --fail http://localhost:8080/
curl --fail http://localhost:8080/helloDoc/count
```

Корневой endpoint возвращает topology `Sharded`, общий счётчик, статистику каждого шарда и число реплик. Endpoint `/helloDoc/count` должен вернуть `items_count` не меньше 1000.

## Остановка

```sh
docker compose down
```

Данные сохраняются в Docker volumes. Команда `docker compose down -v` удаляет их полностью.
