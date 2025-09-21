# pymongo-api

## Как запустить

Запускаем шарды, конфиг и роутер mongodb и приложение

```shell
docker compose up -d
```

Инициализируем конфиг, роутер и шарды + заполняем тестовыми данными

```shell
./scripts/mongo-init.sh
```

## Как проверить

Откройте в браузере http://localhost:8080

## Доступные эндпоинты

Список доступных эндпоинтов, swagger http://localhost:8080/docs