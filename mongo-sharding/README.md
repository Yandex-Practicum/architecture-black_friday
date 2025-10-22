# pymongo-api

## Как запустить

Запускаем mongodb и приложение

```shell
docker compose up -d
```

Скрипт инициации сервера конфигураций, шард и роутера. Наполнение базы данными.
```shell
./mongo-sharding/scripts/mongo-init.sh
```

Для проверки распределения записей по шардам выполнить скрипт:
```shell
./mongo-sharding/scripts/mongo-check.sh
```