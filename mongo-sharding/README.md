# mongo-sharding

## Как запустить

Запускаем mongodb и приложение

```shell
docker compose up -d
```

Подключаемся к серверу конфигурации и делаем инициализацию:

```shell
./scripts/config-server-init.sh
```

Инициализируем шарды:

```shell
./scripts/shard-init.sh
```

Инцициализируем роутер и наполняем его тестовыми данными:

```shell
./scripts/router-init.sh
```

Получится результат — 1000 документов.

## Как проверить

Сделайте проверку на шардах:

```shell
./scripts/check-shard-1.sh
```
Получится результат — 492 документа.

Сделайте проверку на втором шарде:

```shell
./mongo-sharding/scripts/check-shard-2.sh
```

Получится результат — 508 документов.

