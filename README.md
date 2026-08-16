# Architecture Black Friday

Решение проектной работы четвёртого спринта курса «Архитектор ПО». Проект последовательно добавляет шардирование MongoDB, репликацию, Redis, API Gateway, service discovery и CDN.

Архитектурные схемы находятся в файле [architecture.drawio](architecture.drawio). В нём пять страниц:

1. `1 - Sharding` — два шарда MongoDB.
2. `2 - Replication` — по три узла в каждом shard replica set.
3. `3 - Redis cache` — общий кэш приложения.
4. `4 - Gateway and Consul` — APISIX, Consul и несколько экземпляров приложения.
5. `5 - Final with CDN` — итоговая схема с CDN в двух географических регионах и Object Storage как источником статического контента.

Последние две части задания являются архитектурными: APISIX, Consul, CDN и Object Storage показаны на схемах, но не добавлены в локальные Docker-стенды.

## Структура

- `mongo-sharding` — два однокомпонентных shard replica set.
- `mongo-sharding-repl` — два shard replica set по три узла.
- `sharding-repl-cache` — репликация из предыдущего этапа и Redis.
- `api_app` и корневой `compose.yaml` — исходный стенд из шаблона Практикума.

У каждого реализованного этапа есть собственный `README.md`, `compose.yaml`, копия `api_app` и идемпотентный `scripts/init.sh`.

## Быстрый запуск итогового стенда

Для локального запуска нужны Docker и Docker Compose v2.

```bash
cd sharding-repl-cache
docker compose up -d
./scripts/init.sh
```

Проверка:

```bash
docker compose ps
curl http://localhost:8080/
curl http://localhost:8080/docs
```

Корневой эндпоинт должен вернуть:

- `status: "OK"`;
- `mongo_topology_type: "Sharded"`;
- `cache_enabled: true`;
- два шарда с тремя узлами в каждом;
- `collections.helloDoc.documents_count: 1000`.

## Проверка Redis

```bash
docker compose exec -T redis redis-cli FLUSHALL

curl -o /dev/null -s -w 'first:  %{time_total}s\n' \
  http://localhost:8080/helloDoc/users

curl -o /dev/null -s -w 'second: %{time_total}s\n' \
  http://localhost:8080/helloDoc/users
```

Первый запрос занимает около секунды из-за искусственной задержки приложения. Повторный запрос обслуживается из Redis и должен выполняться менее чем за `0.1` секунды.

## Результаты локальной проверки

- В `somedb.helloDoc` создано 1000 документов.
- На `shard1-rs` находится 492 документа, на `shard2-rs` — 508.
- В каждом shard replica set выбран один `PRIMARY`, остальные два узла имеют состояние `SECONDARY`.
- Повторный запуск каждого `scripts/init.sh` не меняет количество документов и не пересоздаёт конфигурацию.
- Для итогового стенда первый запрос занял `1.096641 s`, повторный — `0.026764 s`.

Все три стенда используют одинаковые имена контейнеров и порт `8080`, поэтому запускать их нужно по одному. Перед переходом между этапами выполните `docker compose down` в текущем каталоге.

## Остановка

```bash
docker compose down
```

Для полного удаления данных конкретного стенда:

```bash
docker compose down -v
```
