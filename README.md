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

## Тестирование

Для проверки корректности работы приложения используйте интеграционные тесты:

```shell
docker compose -f compose.yaml -f compose.test.yaml up -d --build
```

Результаты тестов будут выведены в логи контейнера api_test.

```shell
docker compose -f compose.yaml -f compose.test.yaml logs api_test
```

Подробнее о тестах смотрите в [api_app_test/README.md](api_app_test/README.md)

## Проверка кода

Для проверки качества кода используется [Ruff](https://docs.astral.sh/ruff/):

```shell
docker compose -f compose.lint.yaml up --build
```

Подробнее о линтере смотрите в [linter/README.md](linter/README.md)