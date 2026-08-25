# Задание 4. Кэширование Redis

## Как запустить

Запускаем sharding-repl-cache и приложение

Перейти в папку sharding-repl-cache

Выполните:
```shell
docker compose up -d
```

После выполнения docker compose up -d подождите 15-20 секунд, чтобы все контейнеры MongoDB полностью стартовали, и после этого запустите скрипт инициализации из следующего шага. Если скрипт запустить раньше, инициализация конфиг сервера может не пройти.

Инициализация шардирования и наполнение данными

В папке sharding-repl-cache выполните:
```shell
./scripts/init-repl.sh
```

## Как проверить

### Если вы запускаете проект на локальной машине

Откройте в браузере http://localhost:8080

Пример вывода:
```
{"mongo_topology_type":"Sharded","mongo_replicaset_name":null,"mongo_db":"somedb","read_preference":"Primary()","mongo_nodes":[["mongos_router",27020]],"mongo_primary_host":null,"mongo_secondary_hosts":[],"mongo_is_primary":true,"mongo_is_mongos":true,"collections":{"helloDoc":{"documents_count":1000}},"shards":{"shard1":"shard1/shard1-1:27018,shard1-2:27018,shard1-3:27018","shard2":"shard2/shard2-1:27019,shard2-2:27019,shard2-3:27019"},"cache_enabled":true,"status":"OK"}
```

### Перейдя в папку sharding-repl-cache можно проверить распределение документов по шардам

Выполните инструкцию
```shell
docker compose exec -T mongos_router mongosh --port 27020 --quiet --eval "db.getSiblingDB('somedb').helloDoc.getShardDistribution()"
```

Пример вывода:
```
Shard shard1 at shard1/shard1-1:27018,shard1-2:27018,shard1-3:27018
{
  data: '21KiB',
  docs: 478,
  chunks: 1,
  'estimated data per chunk': '21KiB',
  'estimated docs per chunk': 478
}
---
Shard shard2 at shard2/shard2-1:27019,shard2-2:27019,shard2-3:27019
{
  data: '23KiB',
  docs: 522,
  chunks: 1,
  'estimated data per chunk': '23KiB',
  'estimated docs per chunk': 522
}
---
Totals
{
  data: '45KiB',
  docs: 1000,
  chunks: 2,
  'Shard shard1': [
    '47.83 % data',
    '47.8 % docs in cluster',
    '46B avg obj size on shard'
  ],
  'Shard shard2': [
    '52.16 % data',
    '52.2 % docs in cluster',
    '46B avg obj size on shard'
  ]
}
```

### Перейдя в папку sharding-repl-cache можно проверить статус реплик

Выполните инструкцию
```shell
docker compose exec -T shard2-1 mongosh --port 27019 --quiet --eval "rs.status().members.map(m => ({ name: m.name, state: m.stateStr }))"
```
```
[
  { name: 'shard2-1:27019', state: 'PRIMARY' },
  { name: 'shard2-2:27019', state: 'SECONDARY' },
  { name: 'shard2-3:27019', state: 'SECONDARY' }
]
```

```shell
docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval "rs.status().members.map(m => ({ name: m.name, state: m.stateStr }))"
```
```
[
  { name: 'shard1-1:27018', state: 'PRIMARY' },
  { name: 'shard1-2:27018', state: 'SECONDARY' },
  { name: 'shard1-3:27018', state: 'SECONDARY' }
]
```

### Можно проверить скорость работы с не загруженным кэшем(первый запрос) и с загруженным(второй запрос) 

```shell
curl -w "\nВремя: %{time_total}s\n" -o /dev/null -s http://localhost:8080/somedb/users
curl -w "\nВремя: %{time_total}s\n" -o /dev/null -s http://localhost:8080/somedb/users
```
Пример вывода
```
Время: 1.018188s
Время: 0.004782s
```
### Если вы запускаете проект на предоставленной виртуальной машине

Узнать белый ip виртуальной машины

```shell
curl --silent http://ifconfig.me
```

Откройте в браузере http://<ip виртуальной машины>:8080

## Доступные эндпоинты

Список доступных эндпоинтов, swagger http://<ip виртуальной машины>:8080/docs