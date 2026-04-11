# MongoDB Sharding (Задание 2)

В данном каталоге реализована базовая схема шардирования MongoDB (без репликации шардов):
- 1 Config Server (`configSrv`)
- 2 Shards (`shard1`, `shard2`)
- 1 Router (`mongos_router`)

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
docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id : "config_server",
  configsvr: true,
  members: [{ _id : 0, host : "configSrv:27017" }]
});
EOF
```

### 2. Инициализация шардов
```bash
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id : "shard1",
  members: [{ _id : 0, host : "shard1:27018" }]
});
EOF

docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
rs.initiate({
  _id : "shard2",
  members: [{ _id : 0, host : "shard2:27019" }]
});
EOF
```

### 3. Инициализация роутера и наполнение тестовыми данными
```bash
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1/shard1:27018");
sh.addShard("shard2/shard2:27019");

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