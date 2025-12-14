# pymongo-api

## Как запустить

Запускаем mongo и приложение
```shell
docker compose up -d
```

Инициализируем configSrv
```shell
./scripts/config-init.sh
```

Инициализируем shard1
```shell
./scripts/shard1-init.sh
```

Инициализируем shard2
```shell
./scripts/shard2-init.sh
```

Инициализируем mongos и заполняем данными
```shell
./scripts/mongos-init.sh
```

Проверяем кол-во документов в mongos
```
docker compose exec -T mongos mongosh --port 27020
use somedb
db.helloDoc.countDocuments();
exit;
```

Проверяем кол-во документов и реплик в shard1
```
docker compose exec -T shard1-1 mongosh --port 27018
use somedb;
db.helloDoc.countDocuments();
rs.status().members.length;
exit;
```

Проверяем кол-во документов и реплик в shard2
```
docker compose exec -T shard2 mongosh --port 27019
use somedb
db.helloDoc.countDocuments();
rs.status().members.length;
exit;
```

## Как проверить

### Если вы запускаете проект на локальной машине

Откройте в браузере http://localhost:8080

### Если вы запускаете проект на предоставленной виртуальной машине

Узнать белый ip виртуальной машины

```shell
curl --silent http://ifconfig.me
```

Откройте в браузере http://<ip виртуальной машины>:8080

## Доступные эндпоинты

Список доступных эндпоинтов, swagger http://<ip виртуальной машины>:8080/docs