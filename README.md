# pymongo-api

## Как запустить

Запускаем mongodb и приложение

```shell
docker compose up -d
```

Скрипт инициации сервера конфигураций, шард и роутера. Наполнение базы данными
```shell
.sharding-repl-cache/scripts/mongo-init.sh
```

Для проверки распределения записей по шардам выполнить скрипт:
```shell
.sharding-repl-cache/scripts/mongo-check.sh
```

Для отображения информации о mongo откройте в браузере http://localhost:8080

Проверка работы redis:
```markdown
[Скриншот с запросами](sharding-repl-cache/screenshot/img.png)
```

Схемы можно посмотреть здесь:
```markdown
[Схемы приложения](schemas/task.drawio.png)
```
