# Настройка MongoDB с шардированием, репликацией и кешированием

В этом проекте делаем MongoDB с шардированием, репликацией и Redis для кеширования. У каждого шарда по 3 копии (1 основная + 2 резервные) чтобы все работало даже если что-то сломается. Redis нужен чтобы запросы к API работали быстрее.

## Схема компонентов

### Конфигурационный сервер
* `configsvr` — сервер с настройками (порт `27019`)

### Шард 1 (3 копии)
* `shard1` — основная копия (порт `27018`)
* `shard1-secondary1` — резервная копия 1 (порт `27028`)
* `shard1-secondary2` — резервная копия 2 (порт `27038`)

### Шард 2 (3 копии)
* `shard2` — основная копия (порт `27020`)
* `shard2-secondary1` — резервная копия 1 (порт `27030`)
* `shard2-secondary2` — резервная копия 2 (порт `27040`)

### Маршрутизатор
* `mongos` — маршрутизатор (порт `27017`)

### Кеширование
* `redis` — Redis сервер (порт `6379`)

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
# Статус репликации shard1
docker compose exec shard1 mongosh --port 27018 --eval "rs.status()"

# Статус репликации shard2
docker compose exec shard2 mongosh --port 27020 --eval "rs.status()"

# Сколько копий в shard1
docker compose exec shard1 mongosh --port 27018 --eval "rs.status().members.length"

# Сколько копий в shard2
docker compose exec shard2 mongosh --port 27020 --eval "rs.status().members.length"
```

### Проверка кеширования
```bash
# Проверяем что Redis работает
docker compose exec redis redis-cli ping

# Проверяем через API (первый запрос - медленный)
curl -w "Time: %{time_total}s\n" http://localhost:8000/helloDoc/users

# Проверяем через API (второй запрос - быстрый, из кеша)
curl -w "Time: %{time_total}s\n" http://localhost:8000/helloDoc/users
```

### Проверка через API
```bash
# Общее количество документов через API
curl http://localhost:8000/
```

## Ожидаемые результаты

После выполнения всех команд:
- **Общее количество документов**: минимум 1000 (у нас 1500)
- **Количество документов в shard1**: примерно 750
- **Количество документов в shard2**: примерно 750
- **Количество копий в shard1**: 3
- **Количество копий в shard2**: 3
- **API работает**: `http://localhost:8000/` показывает информацию о базе данных
- **Кеширование работает**: второй и следующие вызовы `/helloDoc/users` выполняются меньше 100мс

## Тестирование производительности кеширования

```bash
# Первый запрос (без кеша) - может занять несколько секунд
time curl -s http://localhost:8000/helloDoc/users > /dev/null

# Второй запрос (из кеша) - должен быть меньше 100мс
time curl -s http://localhost:8000/helloDoc/users > /dev/null

# Третий запрос (из кеша) - должен быть меньше 100мс
time curl -s http://localhost:8000/helloDoc/users > /dev/null
```
