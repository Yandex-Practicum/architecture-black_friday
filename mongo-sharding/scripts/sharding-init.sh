#!/bin/bash

# Функция для проверки инициализации репликасета
function is_replica_set_initialized() {
  local container=$1
  local port=$2
  docker exec -i $container mongosh --port $port --quiet --eval \
    "try { rs.status().ok } catch(e) { 0 }" 2>/dev/null | grep -q 1
}

# 1. Config Server
echo "1. Настройка Config Server"
if ! is_replica_set_initialized configSrv 27017; then
  echo "Инициализация Config Server..."
  docker exec -i configSrv mongosh --port 27017 --eval 'rs.initiate({
    _id: "config_server",
    configsvr: true,
    members: [
      {_id: 0, host: "configSrv:27017"}
    ]
  })'
else
  echo "Config Server уже инициализирован"
fi

# 2. Шарды
echo "2. Настройка Shard 1"
if ! is_replica_set_initialized shard1 27018; then
  echo "Инициализация Shard 1..."
  docker exec -i shard1 mongosh --port 27018 --eval 'rs.initiate({
    _id: "shard1",
    members: [
      {_id: 0, host: "shard1:27018"}
    ]
  })'
else
  echo "Shard 1 уже инициализирован"
fi

echo "3. Настройка Shard 2"
if ! is_replica_set_initialized shard2 27019; then
  echo "Инициализация Shard 2..."
  docker exec -i shard2 mongosh --port 27019 --eval 'rs.initiate({
    _id: "shard2",
    members: [
      {_id: 0, host: "shard2:27019"}
    ]
  })'
else
  echo "Shard 2 уже инициализирован"
fi

echo "Очистка БД somedb"
docker exec -i shard1 mongosh --port 27018 --eval '
  const dbs = db.adminCommand("listDatabases").databases.map(d => d.name);
  if (dbs.includes("somedb")) {
    print("База somedb найдена на shard1. Удаляем все коллекции...");
    const collections = db.getSiblingDB("somedb").getCollectionNames();
    collections.forEach(coll => db.getSiblingDB("somedb")[coll].drop());
    print("База очищена.");
  } else {
    print("База somedb не найдена — пропускаем очистку.");
  }
'
docker exec -i shard2 mongosh --port 27019 --eval '
  const dbs = db.adminCommand("listDatabases").databases.map(d => d.name);
  if (dbs.includes("somedb")) {
    print("База somedb найдена на shard2. Удаляем все коллекции...");
    const collections = db.getSiblingDB("somedb").getCollectionNames();
    collections.forEach(coll => db.getSiblingDB("somedb")[coll].drop());
    print("База очищена.");
  } else {
    print("База somedb не найдена — пропускаем очистку.");
  }
'

echo "Ожидание готовности сервисов (30 секунд)..."
sleep 30

# 4. Настройка mongos
echo "4. Настройка mongos router"
  # Очистка предыдущей конфигурации
docker exec -i mongos_router mongosh --port 27020 --eval '
  try {
    sh.removeShard("shard1/shard1:27018");
    sh.removeShard("shard2/shard2:27019");
    sleep(1000);
  } catch(e) {}'

  # Добавление шардов
docker exec -i mongos_router mongosh --port 27020 --eval '
  sh.addShard( "shard1/shard1:27018")'
docker exec -i mongos_router mongosh --port 27020 --eval '
  sh.addShard( "shard2/shard2:27019")'

  # Настройка шардинга
docker exec -i mongos_router mongosh --port 27020 --eval '
  sh.enableSharding("somedb")'
docker exec -i mongos_router mongosh --port 27020 --eval '
  sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )'

echo "5. Генерация тестовых данных"
docker exec -i mongos_router mongosh --port 27020 --eval '
  db = db.getSiblingDB("somedb");
  for(var i = 0; i < 1000; i++) db.helloDoc.insert({age:i, name:"ly"+i});
'
echo "Записей в somedb:"
docker exec -i mongos_router mongosh "mongodb://localhost:27020/somedb" --eval '
  db.helloDoc.countDocuments();
'

echo "6. Проверка количества тестовых данных в шардах"
echo "Записей в Shard1"
docker exec -i shard1 mongosh --port 27018 --eval '
  db = db.getSiblingDB("somedb");
  db.helloDoc.countDocuments();
'
echo "Записей в Shard2"
docker exec -i shard2 mongosh --port 27019 --eval '
  db = db.getSiblingDB("somedb");
  db.helloDoc.countDocuments();
'

echo "Настройка завершена!"