# Проектная работа: MongoDB Sharding, Replication & Caching

Проект интернет-магазина «Мобильный мир» с настройкой шардирования, репликации и кеширования MongoDB.

## Структура проекта

```
├── ARCHITECTURE.md          # Архитектурный документ (задания 7-10)
├── README.md                # Этот файл
├── schemes/                 # Схемы архитектуры (draw.io)
├── compose.yaml             # Исходный проект (1 MongoDB + 1 API)
├── api_app/                 # Исходное приложение
├── mongo-sharding/          # Задание 2: Шардирование
├── mongo-sharding-repl/     # Задание 3: Шардирование + Репликация
├── sharding-repl-cache/     # Задание 4: Шардирование + Репликация + Redis
└── scripts/                 # Вспомогательные скрипты
```

## Схемы архитектуры

**Финальная схема:** [5_scheme.drawio](schemes/5_scheme.drawio) — полная архитектура с шардированием, репликацией, кешированием, API Gateway, Consul и CDN.

Поэтапное развитие архитектуры (для детального изучения):

| Схема | Описание |
|-------|----------|
| [1_scheme.drawio](schemes/1_scheme.drawio) | Шардирование (2 шарда) |
| [2_scheme.drawio](schemes/2_scheme.drawio) | + Репликация (3 реплики на шард) |
| [3_scheme.drawio](schemes/3_scheme.drawio) | + Кеширование (Redis) |
| [4_scheme.drawio](schemes/4_scheme.drawio) | + API Gateway + Consul (Service Discovery) |
| [5_scheme.drawio](schemes/5_scheme.drawio) | + CDN (финальная версия) |

## Требования

- Docker и Docker Compose
- Минимум 2 CPU и 4 ГБ ОЗУ
- Порты: 8080, 6379, 27017-27020

---

## Быстрый старт

Для запуска проекта с шардированием, репликацией и кешированием:

```bash
cd sharding-repl-cache
docker compose up -d
```

Дождитесь запуска всех контейнеров (12 штук):

```bash
docker compose ps
```

Выполните скрипт инициализации:

```bash
./scripts/init-sharding.sh
```

Или выполните команды вручную:

### 1. Инициализация Config Server Replica Set

```bash
docker compose exec -T configSrv1 mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "config_rs",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv1:27017" },
    { _id: 1, host: "configSrv2:27017" },
    { _id: 2, host: "configSrv3:27017" }
  ]
})
EOF
```

### 2. Инициализация Shard 1 Replica Set

```bash
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1_rs",
  members: [
    { _id: 0, host: "shard1-1:27018" },
    { _id: 1, host: "shard1-2:27018" },
    { _id: 2, host: "shard1-3:27018" }
  ]
})
EOF
```

### 3. Инициализация Shard 2 Replica Set

```bash
docker compose exec -T shard2-1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard2_rs",
  members: [
    { _id: 0, host: "shard2-1:27018" },
    { _id: 1, host: "shard2-2:27018" },
    { _id: 2, host: "shard2-3:27018" }
  ]
})
EOF
```

### 4. Ожидание инициализации

```bash
sleep 20
```

### 5. Добавление шардов в кластер

```bash
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1_rs/shard1-1:27018,shard1-2:27018,shard1-3:27018")
sh.addShard("shard2_rs/shard2-1:27018,shard2-2:27018,shard2-3:27018")
EOF
```

### 6. Включение шардирования

```bash
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.enableSharding("somedb")
use somedb
db.createCollection("helloDoc")
sh.shardCollection("somedb.helloDoc", { "name": "hashed" })
EOF
```

### 7. Наполнение тестовыми данными

```bash
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
use somedb
for (var i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({ name: "user_" + i, age: Math.floor(Math.random() * 100) })
}
EOF
```

---

## Проверка работы

### Проверка приложения

Открыть в браузере: http://localhost:8080

Или выполнить:

```bash
curl http://localhost:8080
```

Ожидаемый результат (JSON):
- `mongo_topology_type: "Sharded"`
- `shards` — список шардов (shard1_rs, shard2_rs)
- `collections.helloDoc.documents_count` >= 1000
- `cache_enabled: true`

### Проверка количества документов в шардах

```bash
# Shard 1
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

# Shard 2
docker compose exec -T shard2-1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

### Проверка репликации

```bash
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.status().members.map(m => ({name: m.name, state: m.stateStr}))
EOF
```

### Проверка кеширования

```bash
# Первый запрос (~1 секунда)
time curl -s http://localhost:8080/helloDoc/users > /dev/null

# Второй запрос (<100мс, из кеша)
time curl -s http://localhost:8080/helloDoc/users > /dev/null
```

---

## Архитектура финального решения

### Компоненты (12 контейнеров)

| Компонент | Контейнеры | Порт |
|-----------|------------|------|
| Config Server RS | configSrv1, configSrv2, configSrv3 | 27017 |
| Shard 1 RS | shard1-1, shard1-2, shard1-3 | 27018 |
| Shard 2 RS | shard2-1, shard2-2, shard2-3 | 27018 |
| MongoDB Router | mongos_router | 27020 |
| Redis Cache | redis | 6379 |
| API Application | pymongo_api | 8080 |

---

## Остановка проекта

```bash
docker compose down
```

Для полной очистки (включая volumes):

```bash
docker compose down -v
```

---

## Документация

- [Финальная схема архитектуры (draw.io)](schemes/5_scheme.drawio)
- [Задание 2: Шардирование](mongo-sharding/README.md)
- [Задание 3: Репликация](mongo-sharding-repl/README.md)
- [Задание 4: Кеширование](sharding-repl-cache/README.md)
- [Задания 7-10: Архитектурный документ](ARCHITECTURE.md)

---

## Используемые технологии

- **MongoDB** — база данных с шардированием и репликацией
- **Redis** — кеширование запросов
- **FastAPI** — API приложение (образ: kazhem/pymongo_api:1.0.0)
- **Docker Compose** — оркестрация контейнеров
