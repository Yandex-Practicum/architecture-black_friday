# Задание 2. Шардирование
## MongoDB Sharding

---

## Архитектура
- **API Application** (порт `8080`) — веб-приложение
- **Mongos Router** (порт `27017`) — точка входа для клиентских приложений
- **Config Server** (порт `27018`) — хранит метаданные кластера
- **Shard 1** (порт `27011`) — первый шард
- **Shard 2** (порт `27012`) — второй шард

---

## Запуск

### 1. Поднять кластер
```bash
docker compose up -d
```

### 2. Инициализация шардирования
```bash
./scripts/mongo-init.sh
```

Скрипт выполнит:
1. Инициализацию Config Server replica set
2. Инициализацию replica set для каждого шарда
3. Добавление шардов в кластер через mongos
4. Включение шардирования для базы данных somedb
5. Создание шардированной коллекции helloDoc
6. Заполнение коллекции тестовыми документами
7. Проверку количества документов на каждом шарде

---
## Проверка работы

#### Веб-интерфейс
Откройте в браузере:
- Локально: http://localhost:8080
- На виртуальной машине: http://<ip_машины>:8080

API возвращает:
- Общее количество документов
- Количество документов по каждому шарду

#### Swagger-документация
- http://localhost:8080/docs

---

## Полезные команды для мониторинга

### Статус кластера

```bash
docker compose exec -T mongos mongosh --port 27017 --quiet --eval "sh.status()"
```

### Распределение данных по шардам

```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
use somedb
db.helloDoc.getShardDistribution()
EOF
```

### Количество документов в каждом шарде

#### Shard 1:
```bash
docker compose exec -T shard1 mongosh --port 27011 --quiet --eval "use somedb" --eval "db.helloDoc.countDocuments()"
```

#### Shard 2:
```bash
docker compose exec -T shard2 mongosh --port 27012 --quiet --eval "use somedb" --eval "db.helloDoc.countDocuments()"
```

### Общее количество через mongos:
```bash
docker compose exec -T mongos mongosh --port 27017 --quiet --eval "use somedb" --eval "db.helloDoc.countDocuments()"
```