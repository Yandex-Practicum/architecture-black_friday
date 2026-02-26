#!/bin/sh
set -e

# -------------------------
# 1. Ждем готовность config-server
# -------------------------
echo "Ожидаем готовность config-server..."
until mongosh --host config-server --port 27019 --eval "db.adminCommand('ping')" >/dev/null 2>&1; do
  sleep 2
done

# -------------------------
# 2. Инициализация реплика-сетов
# -------------------------
echo "Инициализация shard1ReplSet..."
mongosh --host shard1-primary --port 27018 --eval "
rs.initiate({
  _id: 'shard1ReplSet',
  members: [
    { _id: 0, host: 'shard1-primary:27018' },
    { _id: 1, host: 'shard1-secondary1:27028' },
    { _id: 2, host: 'shard1-secondary2:27038' }
  ]
})
"

echo "Инициализация shard2ReplSet..."
mongosh --host shard2-primary --port 27020 --eval "
rs.initiate({
  _id: 'shard2ReplSet',
  members: [
    { _id: 0, host: 'shard2-primary:27020' },
    { _id: 1, host: 'shard2-secondary1:27030' },
    { _id: 2, host: 'shard2-secondary2:27040' }
  ]
})
"

echo "Инициализация configReplSet..."
mongosh --host config-server --port 27019 --eval "
rs.initiate({
  _id: 'configReplSet',
  configsvr: true,
  members: [
    { _id: 0, host: 'config-server:27019' }
  ]
})
"

# -------------------------
# 3. Ждем пока реплики стабилизируются
# -------------------------
echo "Ждем стабилизации реплик..."
sleep 15

# -------------------------
# 4. Добавляем шарды в configReplSet
# -------------------------
echo "Добавляем шарды в mongos..."
mongosh --host mongos --port 27017 --eval "
sh.addShard('shard1ReplSet/shard1-primary:27018');
sh.addShard('shard2ReplSet/shard2-primary:27020');
sh.enableSharding('somedb');
sh.shardCollection('somedb.helloDoc', { _id: 'hashed' })
"

echo "Заполняем БД somedb коллекцию helloDoc тестовыми данными (5000 записей)"
mongosh --host mongos --port 27017 somedb --eval "
for (let i = 0; i < 5000; i++) {
  db.helloDoc.insertOne({ age: i, name: 'doc_' + i })
}
"

echo "Mongo sharding cluster готов!"

