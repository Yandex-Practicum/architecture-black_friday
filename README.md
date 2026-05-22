
# Выполенные задания

[Задание 1. Планирование](https://github.com/ZergZet/architecture-black_friday/tree/develoment/Task1)

[Задание 2. Шардирование](https://github.com/ZergZet/architecture-black_friday/tree/develoment/mongo-sharding)
[Задание 3. Репликация](https://github.com/ZergZet/architecture-black_friday/tree/develoment/mongo-sharding-repl)
[Задание 4. Кеширование](https://github.com/ZergZet/architecture-black_friday/tree/develoment/sharding-repl-cache)
[Задание 5. Service Discovery и балансировка с API Gateway](https://github.com/ZergZet/architecture-black_friday/tree/develoment/Task5)
[Задание 6. CDN](https://github.com/ZergZet/architecture-black_friday/tree/develoment/Task6)

# описание исходного pymongo-api

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
