# mongo-sharding

## Как запустить

Запускаем mongodb и приложение

```shell
docker compose up -d
```

Подключаемся к серверу конфигурации и делаем инициализацию:

```shell
./scripts/mongo-sharding/config-server-init.sh
```

Инициализируем шарды:

```shell
./scripts/mongo-sharding/shard-init.sh
```

Инициализируем шарды:

```shell
./scripts/mongo-sharding/shard-init.sh
```

Инцициализируем роутер и наполняем его тестовыми данными:

```shell
./scripts/mongo-sharding/router-init.sh
```

Получится результат — 1000 документов.

## Как проверить

Сделайте проверку на шардах:

```shell
./scripts/mongo-sharding/check-shard-1.sh
```
Получится результат — 492 документа.

Сделайте проверку на втором шарде:

```shell
./scripts/mongo-sharding/check-shard-2.sh
```

Получится результат — 508 документов.

