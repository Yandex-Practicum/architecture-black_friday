# sharding-repl-cache

Финальный стенд для проверки (шардирование + репликация + Redis кеш).

## Запуск

```bash
docker compose up -d
```

## Инициализация MongoDB

```bash
chmod +x scripts/init-repl-sharding.sh scripts/mongo-init.sh
./scripts/init-repl-sharding.sh
./scripts/mongo-init.sh
```

## Проверка MongoDB

Общее количество документов (должно быть >= 1000):

```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
db.helloDoc.countDocuments()
EOF
```

Проверка шардов и реплик:

```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
sh.status()
EOF
```

## Проверка кеша

Первый вызов будет медленнее, повторные должны быть быстрее:

```bash
time curl -s http://localhost:8080/helloDoc/users > /dev/null
time curl -s http://localhost:8080/helloDoc/users > /dev/null
```

Второй и следующие вызовы должны быть меньше 100ms.

## Полезные ссылки

- API: `http://localhost:8080`
- Swagger: `http://localhost:8080/docs`
