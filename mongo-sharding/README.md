# MongoDB шардинг
## Инструкция по запуску:

### Поднимаем сервисы:
```shell
docker compose -f compose.yaml up -d
```

### Запускаем процесс конфигурации:
```shell
./setup.sh
```

### Производим заполнение данными:
```shell
./seed.sh
```

### Делаем просмотр ищеющихся данных:
```shell
./display.sh
```

## Удаление:
```shell
docker compose -f compose.yaml down
docker volume rm mongo-sharding_config-data mongo-sharding_shard1-data mongo-sharding_shard2-data 
```