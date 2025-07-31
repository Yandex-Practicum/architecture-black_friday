# Настройка MongoDB с шардированием, репликацией, кешированием и горизонтальным масштабированием

В этом проекте делаем полную архитектуру для онлайн-магазина "Мобильный мир" с горизонтальным масштабированием. У нас есть MongoDB с шардированием и репликацией, Redis для кеширования, несколько инстансов приложения, API Gateway для балансировки нагрузки и Consul для Service Discovery.

## Схема компонентов

### База данных
* `configsvr` — сервер с настройками (порт `27019`)
* `shard1` — основной шард1 (порт `27018`)
* `shard1-secondary1` — резервная копия шарда1 номер 1 (порт `27028`)
* `shard1-secondary2` — резервная копия шарда1 номер 2 (порт `27038`)
* `shard2` — основной шард2 (порт `27020`)
* `shard2-secondary1` — резервная копия шарда2 номер 1 (порт `27030`)
* `shard2-secondary2` — резервная копия шарда2 номер 2 (порт `27040`)
* `mongos` — маршрутизатор (порт `27017`)

### Кеширование
* `redis` — Redis сервер (порт `6379`)

### Service Discovery
* `consul` — Consul сервер (порт `8500` для UI, `8600` для DNS)

### Приложения
* `pymongo-api-1` — первый инстанс приложения (порт `8001`)
* `pymongo-api-2` — второй инстанс приложения (порт `8002`)
* `pymongo-api-3` — третий инстанс приложения (порт `8003`)

### API Gateway
* `nginx-gateway` — Nginx для балансировки нагрузки (порт `80`)

### База данных
* База данных: `somedb`
* Коллекция: `helloDoc`

## Шаги инициализации кластера

### Windows PowerShell

```powershell
# 1. Настраиваем config сервер
docker compose exec configsvr mongosh --port 27019 --eval "rs.initiate({ _id: 'configReplSet', configsvr: true, members: [{ _id: 0, host: 'configsvr:27019' }] })"

# 2. Настраиваем shard1 с 3 копиями
docker compose exec shard1 mongosh --port 27018 --eval "rs.initiate({ _id: 'shard1ReplSet', members: [{ _id: 0, host: 'shard1:27018' }, { _id: 1, host: 'shard1-secondary1:27028' }, { _id: 2, host: 'shard1-secondary2:27038' }] })"

# 3. Настраиваем shard2 с 3 копиями
docker compose exec shard2 mongosh --port 27020 --eval "rs.initiate({ _id: 'shard2ReplSet', members: [{ _id: 0, host: 'shard2:27020' }, { _id: 1, host: 'shard2-secondary1:27030' }, { _id: 2, host: 'shard2-secondary2:27040' }] })"

# 4. Добавляем шарды и включаем шардирование
docker compose exec mongos mongosh --port 27017 --eval "sh.addShard('shard1ReplSet/shard1:27018'); sh.addShard('shard2ReplSet/shard2:27020'); sh.enableSharding('somedb'); sh.shardCollection('somedb.helloDoc', { _id: 'hashed' })"

# 5. Добавляем данные в коллекцию (минимум 1000 записей)
docker compose exec mongos mongosh --port 27017 somedb --eval "for (let i = 0; i < 1500; i++) { db.helloDoc.insertOne({ age: i, name: 'ly' + i }) }"
```

### Linux / macOS (bash)

```bash
# 1. Настраиваем config сервер
docker compose exec -T configsvr mongosh --port 27019 --quiet <<EOF
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [{ _id: 0, host: "configsvr:27019" }]
})
EOF

# 2. Настраиваем shard1 с 3 копиями
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1ReplSet",
  members: [
    { _id: 0, host: "shard1:27018" },
    { _id: 1, host: "shard1-secondary1:27028" },
    { _id: 2, host: "shard1-secondary2:27038" }
  ]
})
EOF

# 3. Настраиваем shard2 с 3 копиями
docker compose exec -T shard2 mongosh --port 27020 --quiet <<EOF
rs.initiate({
  _id: "shard2ReplSet",
  members: [
    { _id: 0, host: "shard2:27020" },
    { _id: 1, host: "shard2-secondary1:27030" },
    { _id: 2, host: "shard2-secondary2:27040" }
  ]
})
EOF

# 4. Добавляем шарды и включаем шардирование
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
sh.addShard("shard1ReplSet/shard1:27018")
sh.addShard("shard2ReplSet/shard2:27020")
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { _id: "hashed" })
EOF

# 5. Добавляем данные в коллекцию (минимум 1000 записей)
docker compose exec -T mongos mongosh --port 27017 somedb --quiet <<EOF
for (let i = 0; i < 1500; i++) {
  db.helloDoc.insertOne({ age: i, name: "ly" + i })
}
EOF
```

## Проверка результатов

### Общее количество документов
```bash
# Через mongos (общее количество)
docker compose exec mongos mongosh --port 27017 somedb --eval "db.helloDoc.countDocuments()"
```

### Количество документов в шардах
```bash
# Shard1 основная копия
docker compose exec shard1 mongosh --port 27018 somedb --eval "db.helloDoc.countDocuments()"

# Shard2 основная копия
docker compose exec shard2 mongosh --port 27020 somedb --eval "db.helloDoc.countDocuments()"
```

### Проверка репликации
```bash
# Сколько копий в shard1
docker compose exec shard1 mongosh --port 27018 --eval "rs.status().members.length"

# Сколько копий в shard2
docker compose exec shard2 mongosh --port 27020 --eval "rs.status().members.length"
```

### Проверка кеширования
```bash
# Проверяем что Redis работает
docker compose exec redis redis-cli ping

# Проверяем через API Gateway (первый запрос - медленный)
curl -w "Time: %{time_total}s\n" http://localhost/helloDoc/users

# Проверяем через API Gateway (второй запрос - быстрый, из кеша)
curl -w "Time: %{time_total}s\n" http://localhost/helloDoc/users
```

### Проверка горизонтального масштабирования
```bash
# Проверяем что все инстансы работают
curl http://localhost:8001/
curl http://localhost:8002/
curl http://localhost:8003/

# Проверяем балансировку через API Gateway
curl http://localhost/

# Проверяем Consul UI
# Откройте в браузере: http://localhost:8500
```

### Проверка Service Discovery
```bash
# Проверяем что Consul работает
docker compose exec consul consul members

# Проверяем зарегистрированные сервисы
docker compose exec consul consul catalog services
```

## Ожидаемые результаты

После выполнения всех команд:
- **Общее количество документов**: минимум 1000 (у нас 1500)
- **Количество документов в shard1**: примерно 750
- **Количество документов в shard2**: примерно 750
- **Количество копий в shard1**: 3
- **Количество копий в shard2**: 3
- **Количество инстансов приложения**: 3
- **API Gateway работает**: `http://localhost/` показывает информацию о базе данных
- **Кеширование работает**: второй и следующие вызовы `/helloDoc/users` выполняются меньше 100мс
- **Consul работает**: `http://localhost:8500` показывает UI с зарегистрированными сервисами
- **Балансировка работает**: запросы распределяются между тремя инстансами

## Тестирование производительности и отказоустойчивости

```bash
# Тестируем балансировку нагрузки
for i in {1..10}; do
  echo "Запрос $i:"
  curl -w "Time: %{time_total}s\n" http://localhost/helloDoc/users
done

# Тестируем отказоустойчивость (останавливаем один инстанс)
docker compose stop pymongo-api-1

# Проверяем что остальные инстансы продолжают работать
curl http://localhost/

# Запускаем обратно
docker compose start pymongo-api-1
```
