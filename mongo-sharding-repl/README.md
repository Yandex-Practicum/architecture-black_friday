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

### Windows PowerShell

```powershell
# 1. Настраиваем config-server
docker compose exec config-server mongosh --port 27019 --eval "rs.initiate({ _id: 'configReplSet', configsvr: true, members: [{ _id: 0, host: 'config-server:27019' }] })"

# 2. Настраиваем shard1 с 3 репликами
docker compose exec shard1-primary mongosh --port 27018 --eval "rs.initiate({ _id: 'shard1ReplSet', members: [{ _id: 0, host: 'shard1-primary:27018' }, { _id: 1, host: 'shard1-secondary1:27028' }, { _id: 2, host: 'shard1-secondary2:27038' }] })"

# 3. Настраиваем shard2 с 3 репликами
docker compose exec shard2-primary mongosh --port 27020 --eval "rs.initiate({ _id: 'shard2ReplSet', members: [{ _id: 0, host: 'shard2-primary:27020' }, { _id: 1, host: 'shard2-secondary1:27030' }, { _id: 2, host: 'shard2-secondary2:27040' }] })"

# 4. Добавляем шарды и включаем шардирование
docker compose exec mongos mongosh --port 27017 --eval "sh.addShard('shard1ReplSet/shard1-primary:27018'); sh.addShard('shard2ReplSet/shard2-primary:27020'); sh.enableSharding('somedb'); sh.shardCollection('somedb.helloDoc', { _id: 'hashed' })"

# 5. Добавляем данные в коллекцию для тестирования (5000 записей)
docker compose exec mongos mongosh --port 27017 somedb --eval "for (let i = 0; i < 1500; i++) { db.helloDoc.insertOne({ age: i, name: 'doc_' + i }) }"
```

### Linux / macOS (bash)

```bash
# 1. Настраиваем config-server
docker compose exec -T config-server mongosh --port 27019 --quiet <<EOF
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [{ _id: 0, host: "config-server:27019" }]
})
EOF

# 2. Настраиваем shard1 с 3 копиями
docker compose exec -T shard1-primary mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1ReplSet",
  members: [
    { _id: 0, host: "shard1-primary:27018" },
    { _id: 1, host: "shard1-secondary1:27028" },
    { _id: 2, host: "shard1-secondary2:27038" }
  ]
})
EOF

# 3. Настраиваем shard2 с 3 копиями
docker compose exec -T shard2-primary mongosh --port 27020 --quiet <<EOF
rs.initiate({
  _id: "shard2ReplSet",
  members: [
    { _id: 0, host: "shard2-primary:27020" },
    { _id: 1, host: "shard2-secondary1:27030" },
    { _id: 2, host: "shard2-secondary2:27040" }
  ]
})
EOF

# 4. Добавляем шарды и включаем шардирование
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
sh.addShard("shard1ReplSet/shard1-primary:27018")
sh.addShard("shard2ReplSet/shard2-primary:27020")
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { _id: "hashed" })
EOF

# 5. Добавляем данные в коллекцию для тестирования (5000 записей)
docker compose exec -T mongos mongosh --port 27017 somedb --quiet <<EOF
for (let i = 0; i < 5000; i++) {
  db.helloDoc.insertOne({ age: i, name: "doc_" + i })
}
EOF
```

## Проверка результатов

```bash
# Общее количество документов (через mongos)
docker compose exec mongos mongosh --port 27017 somedb --eval "db.helloDoc.countDocuments()"

# Сколько документов в shard1
docker compose exec shard1 mongosh --port 27018 somedb --eval "db.helloDoc.countDocuments()"

# Сколько документов в shard2
docker compose exec shard2 mongosh --port 27020 somedb --eval "db.helloDoc.countDocuments()"
```