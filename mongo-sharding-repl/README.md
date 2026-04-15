# pymongo-api

## Как запустить

Запускаем MongoDB sharded cluster с репликацией и приложение:

```shell
make init-all
```

## Команды по шагам

Если хотите выполнять настройку поэтапно, используйте команды:

```shell
make up
make init-config
make init-shard1
make init-shard2
make add-shards
make enable-sharding
make seed
make check
```

## Что делает каждая команда

### Запуск контейнеров

```shell
make up
```

Поднимает:
- config server replica set
- два шарда, каждый в виде replica set из трёх нод
- mongos
- приложение `pymongo_api`

### Инициализация config server replica set

```shell
make init-config
```

Создаёт replica set для:
- `configSrv1`
- `configSrv2`
- `configSrv3`

### Инициализация replica set для первого шарда

```shell
make init-shard1
```

Создаёт replica set для:
- `shard1_1`
- `shard1_2`
- `shard1_3`

### Инициализация replica set для второго шарда

```shell
make init-shard2
```

Создаёт replica set для:
- `shard2_1`
- `shard2_2`
- `shard2_3`

### Подключение шардов к mongos

```shell
make add-shards
```

Подключает:
- `shard1ReplSet`
- `shard2ReplSet`

к роутеру `mongos`

### Включение шардирования

```shell
make enable-sharding
```

Включает шардирование для базы `somedb` и коллекции `helloDoc`

### Заполнение MongoDB данными

```shell
make seed
```

Запускает скрипт заполнения базы данными через `mongos`

### Проверка кластера

```shell
make check
```

Показывает:
- общее количество документов в базе
- количество документов в первом шарде
- количество документов во втором шарде
- состояние replica set первого шарда
- состояние replica set второго шарда
- состояние config server replica set

## Как проверить приложение

Если вы запускаете проект на локальной машине, откройте:

- http://localhost:8080
- http://localhost:8080/docs

Если вы запускаете проект на предоставленной виртуальной машине, узнайте белый IP:

```shell
curl --silent http://ifconfig.me
```

После этого откройте:

- http://<ip виртуальной машины>:8080
- http://<ip виртуальной машины>:8080/docs
