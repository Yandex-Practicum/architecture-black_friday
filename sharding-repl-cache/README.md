# pymongo-api

## Как запустить

Запускаем mongodb и приложение

```shell
docker compose up -d
```

Скрипт инициации сервера конфигураций, шард и роутера. Наполнение базы данными. Вы должны находится в директории mongo-sharding-cache
```shell
./scripts/mongo-init.sh
```

Для проверки распределения записей по шардам выполнить скрипт (Вы должны находится в директории mongo-sharding-cache):
```shell
./scripts/mongo-check.sh
```

Проверка работы redis:
```markdown
[Скриншот с запросами](screenshot/img.png)
```