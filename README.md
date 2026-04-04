# mongo-sharding
Перейти в директорию mongo_sharding

```shell
cd mongo_sharding
```
Следовать инструкции в mongo_sharding/README.md

# mongo-sharding-repl
Перейти в директорию mongo_sharding_repl

```shell
cd mongo_sharding_repl
```
Следовать инструкции в mongo_sharding_repl/README.md

# sharding-repl-cache
Перейти в директорию sharding_repl_cache

```shell
cd sharding_repl_cache
```
Следовать инструкции в sharding_repl_cache/README.md

# pymongo-api

## Как запустить

Запускаем mongodb и приложение

```shell
docker compose up -d
```

Заполняем mongodb данными

```shell
./scripts/mongo-init.sh
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