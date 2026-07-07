# pymongo-api

## Как запустить

### Запускаем mongodb, заполняем mongodb данными

```shell
./scripts/mongo-init.sh
```

⚠️ В случае проблем с роутером `mongos-router` при повторной инициализации остановите docker, удалив volumes: `docker compose down -v` и инициализируйте mongodb заново

### Запускаем кэширование
Запускаем сервисы Redis
```shell
docker compose config --services | grep -E "redis" | xargs docker compose up -d --build
```

### Запускаем приложение

```shell
docker compose up pymongo_api -d --build
```

## Как проверить

### Наличие записей в базе данных

Запустите скрипт

```shell
./scripts/mongo-check.sh
```

Будет выведено количество:
- записей во всей базе данных
- записей в каждом из шардов
- реплик

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