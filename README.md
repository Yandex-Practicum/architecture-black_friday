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

Откройте в браузере <http://localhost:8080>

### Если вы запускаете проект на предоставленной виртуальной машине

Узнать белый ip виртуальной машины

```shell
curl --silent http://ifconfig.me
```

Откройте в браузере http://<ip виртуальной машины>:8080

## Доступные эндпоинты

Список доступных эндпоинтов, swagger http://<ip виртуальной машины>:8080/docs

## Результат проектной работы

Для проверки итоговой исполняемой конфигурации используйте директорию [sharding-repl-cache](sharding-repl-cache/README.md). Она содержит решение заданий 2, 3 и 4: MongoDB с шардированием, двумя трёхузловыми replica set, Redis и `pymongo-api`.

Запуск выполняется из этой директории в Git Bash с включённой интеграцией Docker Desktop:

```shell
cd sharding-repl-cache
docker compose up -d --build
./scripts/mongo-init.sh
docker compose ps
```

После инициализации:

- API: <http://localhost:8080>
- Swagger: <http://localhost:8080/docs>
- Проверка количества документов: `curl http://localhost:8080/helloDoc/count`
- Проверка кеша: повторные запросы к `http://localhost:8080/helloDoc/users` должны выполняться быстрее 100 мс.

Остановить стенд можно командами `docker compose down`, а удалить данные — `docker compose down -v`.

## Документация и схемы

- [Индекс архитектурной документации](docs/README.md)
- [Карта исходных материалов](docs/internal/inventory.md)
- [Итоговая схема CDN, заданий 1, 5 и 6](docs/design/step5-cdn.drawio)
- [Описание итоговой схемы CDN](docs/design/step5-cdn.md)
- [Предыдущая схема с API Gateway и Consul](docs/design/step4-service-discovery.drawio)

Пошаговые схемы шардирования, репликации и кеширования находятся в [docs/design](docs/design/).
