# MongoDB Sharding with Replication and Redis Cache

## Запуск

### 1. Запуск контейнеров

```bash
docker compose up -d
```

### 2. Инициализация кластера

Выполните скрипт инициализации:

```bash
./scripts/mongo-init.sh
```

### 3. Проверка кэширования

Первый запрос (медленный ~1 сек):

```bash
time curl http://localhost:8080/helloDoc/users
```
