# MongoDB шардинг с репликацией
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
docker volume rm mongo-sharding-repl_config-data mongo-sharding-repl_shard1R1-data mongo-sharding-repl_shard1R2-data mongo-sharding-repl_shard1R3-data mongo-sharding-repl_shard2R1-data mongo-sharding-repl_shard2R2-data mongo-sharding-repl_shard2R3-data
```
