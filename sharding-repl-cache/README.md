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

## Как проверить

### Если вы запускаете проект на локальной машине

Откройте в браузере http://localhost:8080/helloDoc/users

Второй и последующие вызовы эндпоинтаhttp://localhost:8080/helloDoc/users выполняются <100мс

