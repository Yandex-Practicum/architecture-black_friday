# MongoDB sharding, replication and caching

Итоговый стенд находится в директории `sharding-repl-cache`. Он включает
приложение `kazhem/pymongo_api:1.0.0`, Redis и MongoDB с двумя шардами.
Каждый шард состоит из трёх узлов replica set.

## Запуск и инициализация

```sh
cd sharding-repl-cache
docker compose up -d
./scripts/mongo-init.sh
```

Скрипт создаёт replica set `shard1` и `shard2`, подключает их к
шардированному кластеру, включает шардирование коллекции
`somedb.helloDoc` и добавляет 1000 документов.

## Проверка

Проверить состояние контейнеров:

```sh
docker compose ps
```

Открыть информацию о MongoDB и состоянии кеша:

```sh
curl --silent http://localhost:8080
```

В ответе должны отображаться:

- тип топологии `Sharded`;
- два шарда с тремя узлами в каждом;
- не менее 1000 документов;
- `"cache_enabled": true`;
- статус `"OK"`.

Проверить время ответа кешируемого эндпоинта:

```sh
curl --silent \
  --output /dev/null \
  --write-out '%{time_total}\n' \
  http://localhost:8080/helloDoc/users
```

Повторите команду сразу после первого вызова. Второй и последующие запросы
должны выполняться быстрее `0.1` секунды.

Подробные команды проверки MongoDB и replica set приведены в
`sharding-repl-cache/README.md`.

## Остановка

```sh
docker compose down
```
