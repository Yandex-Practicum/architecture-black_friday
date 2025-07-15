#!/bin/bash

# Функция для проверки инициализации репликасета
function is_replica_set_initialized() {
  local container=$1
  local port=$2
  docker exec -i $container mongosh --port $port --quiet --eval \
    "try { rs.status().ok } catch(e) { 0 }" 2>/dev/null | grep -q 1
}

# Функция для проверки доступности сервиса
function is_service_ready() {
  local container=$1
  local port=$2
  docker exec -i $container mongosh --port $port --quiet --eval \
    "try { db.adminCommand({ping:1}).ok } catch(e) { 0 }" 2>/dev/null | grep -q 1
}

# 1. Config Server (3 узла)
echo "1. Настройка Config Server (3 узла)"
if ! is_replica_set_initialized configSrv 27017; then
  echo "Инициализация Config Server..."
  docker exec -i configSrv mongosh --port 27017 --eval 'rs.initiate({
    _id: "config_server",
    configsvr: true,
    members: [
      {_id: 0, host: "configSrv:27017", priority: 2},
      {_id: 1, host: "configSrv2:27017", priority: 1},
      {_id: 2, host: "configSrv3:27017", priority: 1}
    ]
  })'
  echo "Ожидание инициализации Config Server (20 секунд)..."
  sleep 20
else
  echo "Config Server уже инициализирован"
fi

# Проверка статуса Config Server
echo -e "\nСтатус Config Server:"
docker exec -i configSrv mongosh --port 27017 --eval '
  rs.status().members.map(m => `${m.name}: ${m.stateStr} (${m.health})`).join("\n")'

# 2. Шарды (по 3 узла на каждый шард)
echo -e "\n2. Настройка Shard 1 (3 узла)"
if ! is_replica_set_initialized shard1-1 27018; then
  echo "Инициализация Shard 1..."
  docker exec -i shard1-1 mongosh --port 27018 --eval 'rs.initiate({
    _id: "shard1",
    members: [
      {_id: 0, host: "shard1-1:27018", priority: 2},
      {_id: 1, host: "shard1-2:27018", priority: 1},
      {_id: 2, host: "shard1-3:27018", priority: 1}
    ]
  })'
  echo "Ожидание инициализации Shard 1 (20 секунд)..."
  sleep 20
else
  echo "Shard 1 уже инициализирован"
fi

echo -e "\n3. Настройка Shard 2 (3 узла)"
if ! is_replica_set_initialized shard2-1 27019; then
  echo "Инициализация Shard 2..."
  docker exec -i shard2-1 mongosh --port 27019 --eval 'rs.initiate({
    _id: "shard2",
    members: [
      {_id: 0, host: "shard2-1:27019", priority: 2},
      {_id: 1, host: "shard2-2:27019", priority: 1},
      {_id: 2, host: "shard2-3:27019", priority: 1}
    ]
  })'
  echo "Ожидание инициализации Shard 2 (20 секунд)..."
  sleep 20
else
  echo "Shard 2 уже инициализирован"
fi

echo -e "\nПроверка статуса шардов:"
echo "Shard1:"
docker exec -i shard1-1 mongosh --port 27018 --eval '
  rs.status().members.map(m => `${m.name}: ${m.stateStr} (${m.health})`).join("\n")'
echo -e "\nShard2:"
docker exec -i shard2-1 mongosh --port 27019 --eval '
  rs.status().members.map(m => `${m.name}: ${m.stateStr} (${m.health})`).join("\n")'

echo -e "\nОжидание готовности сервисов (30 секунд)..."
sleep 30

# 4. Настройка mongos (3 роутера)
echo -e "\n4. Настройка mongos routers"

# Проверка и настройка каждого роутера
for router in mongos_router mongos_router2 mongos_router3; do
  echo -e "\nПроверка роутера $router..."

  if is_service_ready $router 27020; then
    echo "Статус: ONLINE"

    # Добавление шардов (удалено ошибочное удаление шардов)
    echo "Добавление шардов..."
    docker exec -i $router mongosh --port 27020 --eval '
      try {
        sh.addShard("shard1/shard1-1:27018,shard1-2:27018,shard1-3:27018")
        sh.addShard("shard2/shard2-1:27019,shard2-2:27019,shard2-3:27019")
      } catch(e) {
        print("Ошибка при добавлении шардов:", e)
      }'

    # Настройка шардинга
    echo "Настройка шардинга..."
    docker exec -i $router mongosh --port 27020 --eval '
      try {
        sh.enableSharding("somedb")
        sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )
      } catch(e) {
        print("Ошибка при настройке шардинга:", e)
      }'

    # Проверка конфигурации
    echo -e "\nКонфигурация $router:"
    docker exec -i $router mongosh --port 27020 --eval '
      sh.status({
        verbose: true,
        filter: {
          "shards.name": /shard/
        }
      })'
  else
    echo "Статус: OFFLINE (роутер недоступен)"
  fi
done

# 5. Генерация тестовых данных (только через первый роутер)
echo -e "\n5. Генерация тестовых данных"
docker exec -i mongos_router mongosh --port 27020 --eval '
  db = db.getSiblingDB("somedb");
  try {
    for(var i = 0; i < 1000; i++) {
      db.helloDoc.insertOne({age:i, name:"ly"+i});
    }
    print("Добавлено 1000 тестовых документов");
  } catch(e) {
    print("Ошибка при генерации данных:", e);
  }
'

echo -e "\n6. Проверка данных"
echo "Общее количество записей:"
docker exec -i mongos_router mongosh --port 27020 --eval '
  db.getSiblingDB("somedb").helloDoc.countDocuments()'

echo -e "\nЗаписей в Shard1:"
docker exec -i shard1-1 mongosh --port 27018 --eval '
  db = db.getSiblingDB("somedb");
  db.helloDoc.countDocuments();
'
echo -e "\nЗаписей в Shard2:"
docker exec -i shard2-1 mongosh --port 27019 --eval '
  db = db.getSiblingDB("somedb");
  db.helloDoc.countDocuments();
'

# 7. Проверка репликации
echo -e "\n7. Проверка репликации"
echo "Статус Config Server:"
docker exec -i configSrv mongosh --port 27017 --eval '
  rs.status().members.map(m => `${m.name}: ${m.stateStr}`).join("\n")'
echo -e "\nСтатус Shard1:"
docker exec -i shard1-1 mongosh --port 27018 --eval '
  rs.status().members.map(m => `${m.name}: ${m.stateStr}`).join("\n")'
echo -e "\nСтатус Shard2:"
docker exec -i shard2-1 mongosh --port 27019 --eval '
  rs.status().members.map(m => `${m.name}: ${m.stateStr}`).join("\n")'

# 8. Проверка балансировки запросов между роутерами
echo -e "\n8. Проверка балансировки между роутерами"
for router in mongos_router mongos_router2 mongos_router3; do
  if is_service_ready $router 27020; then
    echo "Статистика $router:"
    docker exec -i $router mongosh --port 27020 --eval '
      db.adminCommand({serverStatus:1}).connections'
  fi
done

# 9. Итоговый статус
echo -e "\n9. Итоговый статус системы:"
echo "Роутеры:"
for router in mongos_router mongos_router2 mongos_router3; do
  status=$(docker exec -i $router mongosh --port 27020 --quiet --eval '
    try {
      db.adminCommand({ping:1}).ok ? "ONLINE" : "DEGRADED"
    } catch(e) {
      "OFFLINE"
    }')
  echo "  $router: $status"
done

echo -e "\nШарды:"
echo "  Shard1:"
docker exec -i shard1-1 mongosh --port 27018 --quiet --eval '
  rs.status().members.map(m => `    ${m.name}: ${m.stateStr}`).join("\n")'
echo "  Shard2:"
docker exec -i shard2-1 mongosh --port 27019 --quiet --eval '
  rs.status().members.map(m => `    ${m.name}: ${m.stateStr}`).join("\n")'

echo -e "\nConfig Servers:"
docker exec -i configSrv mongosh --port 27017 --quiet --eval '
  rs.status().members.map(m => `    ${m.name}: ${m.stateStr}`).join("\n")'

echo -e "\nНастройка завершена!"