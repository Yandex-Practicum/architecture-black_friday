# mongo-sharding-repl

Шардирование MongoDB (2 шарда) с репликацией (по 3 реплики на каждый шард и config server).

## Запуск

1. Запустить сервисы:
```bash
docker compose up -d
```

2. Инициализировать репликацию и шардирование:
```bash
bash ./scripts/replication-init.sh
```

3. Наполнить базу данными (1000 документов):
```bash
bash ./scripts/mongo-init.sh
```

4. Проверить работу:
- Открыть http://localhost:8080
