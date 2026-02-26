# Настройка MongoDB с шардированием

Настраиваем MongoDB с шардированием и репликацией.
Есть два шарда `shard1` и `shard2` и по 3 реплики на каждом shard1-primary, shard2-primary, один сервер с настройками `config-server` и маршрутизатор `mongos` (для демо используем
1 инстанс).
После запуска всех контейнеров нужно выполнить несколько шагов.

## Схема компонентов

* `config-server` — сервер с настройками (порт `27019`)
* `shard1-primary`, `shard1-secondary1`, `shard1-secondary2` — реплики первого шарда (порты `27018`, `27028`, `27038`)
* `shard2-primary`, `shard2-secondary1`, `shard2-secondary2` — реплики второго шарда (порты `27020`, `27030`, `27040`)
* `mongos` — маршрутизатор (порт `27017`)
* База данных: `somedb`
* Коллекция: `helloDoc`

## Шаги инициализации кластера

```bash
# Запускаем контейнеры проекта
docker compose up -d
```

```bash
# Единоразово запускаем инициализацию шардов и реплик, а также проливку тестовых данных
docker compose exec -T mongos sh -c "/mongo-init.sh"
```

## Проверка результатов

```bash
# Общее количество документов (через mongos)
docker compose exec mongos mongosh --port 27017 somedb --eval "db.helloDoc.countDocuments()"
```

```bash
# Количество документов в shard1-primary1
docker compose exec shard1-primary mongosh --port 27018 somedb --eval "db.helloDoc.countDocuments()"
```

```bash
# Количество документов в shard1-primary2
docker compose exec shard2-primary mongosh --port 27020 somedb --eval "db.helloDoc.countDocuments()"
```

### Проверка репликации

```bash
# Статус реплик shard1
docker compose exec shard1-primary mongosh --port 27018 --eval "rs.status()"
```

```bash
# Количество реплик в shard1
docker compose exec shard1-primary mongosh --port 27018 --eval "rs.status().members.length"
```

```bash
# Статус реплик shard2
docker compose exec shard2-primary mongosh --port 27020 --eval "rs.status()"
```

```bash
# Количество реплик в shard2
docker compose exec shard2-primary mongosh --port 27020 --eval "rs.status().members.length"
```
```bash
# Общая информация по БД
curl http://localhost:8080/
```

### Проверка кеширования
```bash
# Проверяем что Redis работает
docker compose exec redis redis-cli ping
```
```bash
# Проверяем первый запрос, около 1 сек на непрогретом кэше
time curl http://localhost:8080/helloDoc/users > /dev/null
```
```bash
# Проверяем второй запрос, около 0.5 сек из кэша
time curl http://localhost:8080/helloDoc/users > /dev/null
```