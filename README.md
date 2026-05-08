# architecture-black_friday

Репозиторий с решением проектной работы 4 спринта.

## Структура

- `mongo-sharding` — шардирование (2 шарда)
- `mongo-sharding-repl` — шардирование + репликация (по 3 реплики на каждый шард)
- `sharding-repl-cache` — финальный стенд: шардирование + репликация + Redis cache
- `architecture-final.drawio` — итоговая схема (включает шардирование, репликацию, кеш, API Gateway, Consul, CDN)

## Что проверять ревьюеру

Основная директория для проверки заданий 2, 3, 4:

```bash
cd sharding-repl-cache
```

## Запуск финального стенда

```bash
docker compose up -d
chmod +x scripts/init-repl-sharding.sh scripts/mongo-init.sh
./scripts/init-repl-sharding.sh
./scripts/mongo-init.sh
```

## Проверки

Статус сервисов:

```bash
docker compose ps
```

Общее количество документов (должно быть >= 1000):

```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
EOF
```

Проверка шардирования и реплик:

```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
sh.status()
EOF
```

Проверка кеша (второй и следующие запросы < 100ms):

```bash
time curl -s http://localhost:8080/helloDoc/users > /dev/null
time curl -s http://localhost:8080/helloDoc/users > /dev/null
```

Проверка API:

- `http://localhost:8080`
- `http://localhost:8080/docs`

## Используемый образ приложения

Во всех новых стендах используется `kazhem/pymongo_api:1.0.0`.