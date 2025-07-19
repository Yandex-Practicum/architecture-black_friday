# pymongo-api

## Как запустить

Перейти в папку mongo-sharding

Запускаем mongodb и приложение

```shell
docker compose up -d
```

Подключиться и инициализировать сервис конфигурации

```shell
./scripts/config-service.sh
```

Инициализировать шарды
```shell
./scripts/init-shard.sh
```

Инцициализировать роутер и наполнить его тестовыми данными - Получите вывод количества созданных документов
```shell
./scripts/init-route.sh
```

Сделайте проверку на шардах:
на 1

```shell
./scripts/check-shard1.sh
```
на 2

```shell
./scripts/check-shard2.sh
```