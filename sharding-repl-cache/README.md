# MongoDB Sharding + Cache (Задание 4)

В данном каталоге реализована схема шардирования MongoDB с добавлением слоя кеширования:
- Config Server Replica Set (3 узла: `configSrv1`, `configSrv2`, `configSrv3`)
- Shard 1 Replica Set (3 узла: `shard1-1`, `shard1-2`, `shard1-3`)
- Shard 2 Replica Set (3 узла: `shard2-1`, `shard2-2`, `shard2-3`)
- 1 Router (`mongos_router`)
- 1 Redis Cache (`redis`)

## Как запустить

1. Поднимите контейнеры в фоновом режиме:
```bash
docker compose up -d
```

2. Дождитесь, пока контейнеры перейдут в статус `healthy` (около 10-15 секунд).

## Инициализация кластера

Выполните следующие команды по очереди для настройки серверов и наполнения базы данными.

### 1. Инициализация конфигурационного сервера
```bash
docker compose exec -T configSrv1 mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id : "config_server",
  configsvr: true,
  members: [
    { _id : 0, host : "configSrv1:27017" },
    { _id : 1, host : "configSrv2:27017" },
    { _id : 2, host : "configSrv3:27017" }
  ]
});
EOF
```

### 2. Инициализация шардов
```bash
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id : "shard1",
  members: [
    { _id : 0, host : "shard1-1:27018" },
    { _id : 1, host : "shard1-2:27018" },
    { _id : 2, host : "shard1-3:27018" }
  ]
});
EOF

docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
rs.initiate({
  _id : "shard2",
  members: [
    { _id : 0, host : "shard2-1:27019" },
    { _id : 1, host : "shard2-2:27019" },
    { _id : 2, host : "shard2-3:27019" }
  ]
});
EOF
```

### 3. Инициализация роутера и наполнение тестовыми данными
```bash
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1/shard1-1:27018,shard1-2:27018,shard1-3:27018");
sh.addShard("shard2/shard2-1:27019,shard2-2:27019,shard2-3:27019");

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" });

use somedb;
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i});
EOF
```

## Как проверить

После выполнения всех команд откройте в браузере или выполните curl запрос:
http://localhost:8080/ (или http://<ip_виртуальной_машины>:8080/)

Приложение должно вернуть JSON, в котором будет указано:
- Общее количество документов в базе (должно быть 1000).
- Количество документов, распределенных на `shard1`.
- Количество документов, распределенных на `shard2`.

### Проверка кеширования (Задание 4)

В приложении реализовано кеширование для эндпоинта `/<collection_name>/users`.
Для проверки выполните GET-запрос: `http://localhost:8080/helloDoc/users`

1. **Первый запрос:** Пойдет напрямую в MongoDB (может занять некоторое время), после чего данные сохранятся в Redis.
2. **Второй и последующие запросы:** Будут отдаваться из Redis. Вы увидите, что скорость ответа значительно увеличилась и составляет `< 100мс`.