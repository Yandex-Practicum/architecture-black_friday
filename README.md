# pymongo-api: финальный стенд

Финальная реализация находится в директории [`sharding-repl-cache`](sharding-repl-cache) и включает:

- два шарда MongoDB: `shard1-rs` и `shard2-rs`;
- по три реплики в каждом шарде;
- `configSrv` и маршрутизатор `mongos`;
- базу `somedb` и шардированную коллекцию `helloDoc`;
- Redis для кеширования `GET /<collection_name>/users`;
- FastAPI-приложение `pymongo-api` на порту `8080`.

Итоговая архитектурная схема со всеми этапами находится в [`task1.drawio`](task1.drawio). API Gateway, Consul и CDN представлены на итоговых страницах схемы; запускаемый Docker Compose стенд демонстрирует финальную конфигурацию MongoDB и Redis.

## Требования

- Docker с Compose v2 (`docker compose`) или standalone Compose (`docker-compose`);
- свободный порт `8080`;
- доступ к Docker Hub для загрузки `mongo:8.0-noble`, `redis:7.2-alpine` и `python:3.12-alpine3.22`. (Поменяли версии для mongodb и python так как полный запуск заблокирован внешним registry: загрузка dh-mirror.gitverse.ru/mongo:latest оборвалась с unexpected EOF до создания контейнеров. Также VS Code показывает унаследованные уязвимости python:3.12.1-slim)

## Запуск

Все команды ниже выполняются из корня репозитория:

```sh
cd sharding-repl-cache
docker compose up -d --build
chmod +x init-sharding.sh
./init-sharding.sh
```

Если доступна только standalone-команда, в командах для Compose используйте `docker-compose`. Скрипт `init-sharding.sh` выбирает доступный вариант автоматически.

Скрипт:

1. Ожидает готовности всех MongoDB-инстансов.
2. Создаёт config server replica set.
3. Создаёт `shard1-rs` и `shard2-rs` по три реплики.
4. Регистрирует оба шарда в `mongos`.
5. Включает шардирование `somedb.helloDoc` по hashed-ключу `name`.
6. Создаёт 1000 документов и выводит их распределение.
7. Проверяет количество реплик и очищает Redis.

Первичная настройка обычно занимает 20–60 секунд. Все циклы ожидания имеют timeout 120 секунд. Скрипт можно запускать повторно: конфигурация replica set сохраняется, а тестовые данные пересоздаются.

Проверить, что все 10 сервисов запущены:

```sh
docker compose ps
```

## Проверка приложения

Откройте http://localhost:8080 или выполните:

```sh
curl --fail http://localhost:8080/
curl --fail http://localhost:8080/helloDoc/count
```

Корневой endpoint должен показать:

- `mongo_topology_type: "Sharded"`;
- `mongo_db: "somedb"`;
- `collections.helloDoc.documents_count` не меньше `1000`;
- количество документов отдельно в `shard1-rs` и `shard2-rs`;
- `replicas_count: 3` для каждого шарда;
- `cache_enabled: true`.

Endpoint `/helloDoc/count` должен вернуть `items_count` не меньше `1000`.

Swagger UI доступен по адресу http://localhost:8080/docs.

## Проверка MongoDB

Общий счётчик и распределение документов по шардам:

```sh
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
db.helloDoc.getShardDistribution()
EOF
```

Ожидается два шарда, а сумма документов на них должна равняться общему количеству и быть не меньше `1000`.

Проверить состав replica set можно через любой его узел, независимо от того, какой узел был выбран primary:

```sh
docker compose exec -T shard1-1 mongosh --port 27018 --quiet \
	--eval 'rs.status().members.map(({name, stateStr, health}) => ({name, stateStr, health}))'

docker compose exec -T shard2-1 mongosh --port 27018 --quiet \
	--eval 'rs.status().members.map(({name, stateStr, health}) => ({name, stateStr, health}))'
```

Для каждого шарда должно отображаться три узла: один `PRIMARY`, два `SECONDARY`, у всех `health: 1`.

## Проверка Redis

Очистите кеш и выполните два одинаковых запроса:

```sh
docker compose exec -T redis redis-cli FLUSHDB

curl --output /dev/null --silent --write-out 'first:  %{time_total}s\n' \
	http://localhost:8080/helloDoc/users

curl --output /dev/null --silent --write-out 'second: %{time_total}s\n' \
	http://localhost:8080/helloDoc/users
```

Первый запрос выполняется около одной секунды и сохраняет ответ в Redis. Второй и последующие запросы в течение TTL 60 секунд должны выполняться быстрее `0.100` секунды.

Проверить наличие кеша:

```sh
docker compose exec -T redis redis-cli DBSIZE
docker compose exec -T redis redis-cli --scan
```

После запроса `/helloDoc/users` команда `DBSIZE` должна вернуть значение не меньше `1`.

## Диагностика

Если стенд не запускается:

```sh
docker compose ps -a
docker compose logs pymongo-api mongos configSrv redis
docker compose logs shard1-1 shard1-2 shard1-3
docker compose logs shard2-1 shard2-2 shard2-3
```

Если порт `8080` уже занят, остановите ранее запущенный Compose-проект перед запуском этого стенда.

## Остановка

```sh
docker compose down
```

Данные MongoDB и Redis сохраняются в Docker volumes. Команда `docker compose down -v` удаляет все данные стенда и должна использоваться только для полного сброса окружения.
