# Mongo Sharding with Redis Cache Example

Этот проект демонстрирует развертывание MongoDB с шардированием, добавление тестовой коллекции `helloDoc` с 50 000 документов, распределение данных по двум шардам и **кэширование с помощью Redis** для улучшения производительности API.

## Особенности проекта

- **MongoDB Sharding**: Горизонтальное масштабирование с 2 шардами по 3 реплики
- **Redis Caching**: Кэширование API запросов для улучшения производительности
- **FastAPI**: Современный веб-фреймворк с автоматической документацией
- **Docker Compose**: Простое развертывание всей инфраструктуры
- **Мониторинг**: Логирование и диагностика всех компонентов

## Структура проекта

```
sharding-repl-cache/
├── api_app/                 # FastAPI приложение
│   ├── app.py              # Основной код с кэшированием
│   ├── Dockerfile          # Контейнер приложения
│   └── requirements.txt    # Python зависимости
├── redis/                  # Конфигурация Redis
│   └── redis.conf         # Настройки Redis сервера
├── scripts/               # Скрипты инициализации
│   └── mongo-init.sh     # Скрипт настройки MongoDB
├── compose.yaml          # Docker Compose конфигурация
├── simple_test.py        # Тест производительности кэширования
└── README.md            # Документация
```

## Шаг 1. Запуск Docker Compose

В корне проекта:

```bash
docker compose up -d
```
Контейнеры, которые будут созданы:
- 2 реплики-сета по каждому шарду (shard1, shard2) (итого 6)
- Конфигурационный сервер (configSrv)
- Роутер (mongos_router)
- **Redis сервер для кэширования (redis_1)**
- **FastAPI приложение с кэшированием (pymongo_api)**
## Шаг 2. Инициализация сервисов по назначению
### Конфигурация
Открываем контейнер конфигурации 
```bash
docker exec -it configSrv mongosh --port 27017
```
Инициализируем конфигурацию
```bash
> rs.initiate(
  {
    _id : "config_server",
       configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" }
    ]
  }
);

```
Выход через `exit`
### Реплики сет шардов
Открываем любой контейнер из реплики сета  шарда №1
```bash
docker exec -it shard1_1 mongosh --port 27018
```
Инициализируем реплику сет шарда №1
```bash
> rs.initiate({
  _id: "shard1",
  members: [
    { _id: 0, host: "shard1_1:27018" },
    { _id: 1, host: "shard1_2:27018" },
    { _id: 2, host: "shard1_3:27018" }
  ]
});
```
Выход через `exit`

ткрываем любой контейнер из реплики сета  шарда №2
```bash
docker exec -it shard2_1 mongosh --port 27019
```
Инициализируем реплику сет шарда №2
```bash
> rs.initiate({
  _id: "shard2",
  members: [
    { _id: 0, host: "shard2_1:27019" },
    { _id: 1, host: "shard2_2:27019" },
    { _id: 2, host: "shard2_3:27019" }
  ]
});
```
Выход через `exit`

### Настройки роутера

Открываем контейнер шарда №2
```bash
docker exec -it mongos_router mongosh --port 27020
```
Регистрируем реплики-сет по очереди 
```bash
> sh.addShard("shard1/shard1_1:27018,shard1_2:27018,shard1_3:27018");
> sh.addShard("shard2/shard2_1:27019,shard2_2:27019,shard2_3:27019");
```
Инициализируем `somedb` и включаем шардирование
```bash
> sh.enableSharding("somedb");
```
Создаем коллекцию
```bash
> db.createCollection("helloDoc")
```
Задаем правило шардирования коллекции
```bash
> sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )
```
Переключаемся на БД и вставляем данные 
```bash
>use somedb
>const names = ["Alice","Bob","Charlie","Diana","Eve","Frank","Grace","Hank","Ivy","Jack"];
const docs = [];

for (let i = 0; i < 50000; i++) {
  const randomName = names[Math.floor(Math.random() * names.length)] + "_" + i;
  docs.push({
    _id: UUID(),
    name: randomName,
    age: Math.floor(Math.random() * 100)
  });

  if (docs.length === 1000) {
    db.helloDoc.insertMany(docs);
    docs.length = 0;
  }
}

// Вставляем остаток
if (docs.length > 0) db.helloDoc.insertMany(docs);

// Проверяем количество документов во всех шардах
>db.helloDoc.countDocuments()
```

## Шаг 3. Настройка Redis для кэширования

### Конфигурация Redis

Redis настроен с помощью файла `redis/redis.conf`:

```conf
port 6379
cluster-config-file nodes.conf
cluster-node-timeout 5000
appendonly yes
```

**Описание параметров:**
- `port 6379` - стандартный порт Redis
- `cluster-config-file nodes.conf` - файл конфигурации кластера
- `cluster-node-timeout 5000` - таймаут узла кластера (5 секунд)
- `appendonly yes` - включение AOF (Append Only File) для персистентности
