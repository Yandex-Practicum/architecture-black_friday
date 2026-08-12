# MongoDB sharding

Проект запускает `pymongo-api`, маршрутизатор `mongos`, config server и два шарда MongoDB. База `somedb`, коллекция `helloDoc`; ключ шардирования — hashed-поле `name`.

MongoDB закреплена на `8.0.29-noble`. Для запуска на Linux kernel 6.19 во всех MongoDB-сервисах установлена переменная `MONGO_TCMALLOC_PER_CPU_CACHE_SIZE_BYTES=0`, отключающая несовместимый per-CPU cache TCMalloc (SERVER-121912).

## Запуск и инициализация

Из директории `mongo-sharding` выполните:

```sh
docker compose up -d --build
chmod +x init-sharding.sh
./init-sharding.sh
```

Скрипт ожидает готовности MongoDB, инициализирует replica set config server и каждого шарда, регистрирует шарды в `mongos`, включает шардирование и создаёт 1000 документов. Скрипт можно запускать повторно: тестовые документы будут пересозданы.

Скрипт автоматически выбирает доступную команду `docker compose` или `docker-compose`. В примерах ниже используйте тот же вариант, который доступен в вашей системе.

## Проверка

Общее количество документов через `mongos`:

```sh
docker-compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
db.helloDoc.getShardDistribution()
EOF
```

Количество документов непосредственно на каждом шарде:

```sh
docker-compose exec -T shard1 mongosh --port 27018 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
EOF

docker-compose exec -T shard2 mongosh --port 27018 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
EOF
```

Проверка приложения:

```sh
curl --fail http://localhost:8080/
curl --fail http://localhost:8080/helloDoc/count
```

Ответ корневого endpoint должен содержать `mongo_topology_type: Sharded`, оба шарда и `collections.helloDoc.documents_count` не меньше 1000.

## Остановка

```sh
docker-compose down
```

Данные хранятся в Docker volumes. Команда `docker-compose down -v` удаляет их полностью.
