# mongo-sharding

Базовое шардирование MongoDB (2 шарда) с mongos и приложением pymongo-api.

## Запуск

1. Запустить сервисы:
```bash
docker compose up -d
```

2. Инициализировать шардирование:
```bash
bash ./scripts/sharding-init.sh
```

3. Наполнить базу данными (1000 документов):
```bash
bash ./scripts/mongo-init.sh
```

4. Проверить работу:
- Открыть http://localhost:8080
