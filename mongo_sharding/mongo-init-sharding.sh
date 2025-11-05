#!/bin/bash

# Скрипт инициализации MongoDB Sharding

set -e

echo "========================================="
echo "MongoDB Sharding Initialization Script"
echo "========================================="
echo ""

# Шаг 1: Инициализация Config Server
echo ""
echo "[1/7] Initializing Config Server..."
docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [{ _id: 0, host: "configSrv:27017" }]
});
EOF
echo "✓ Config Server initialized"

# Шаг 2: Инициализация Shard 1
echo ""
echo "[2/7] Initializing Shard 1..."
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1",
  members: [{ _id: 0, host: "shard1:27018" }]
});
EOF
echo "✓ Shard 1 initialized"

# Шаг 3: Инициализация Shard 2
echo ""
echo "[3/7] Initializing Shard 2..."
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
rs.initiate({
  _id: "shard2",
  members: [{ _id: 1, host: "shard2:27019" }]
});
EOF
echo "✓ Shard 2 initialized"

# Шаг 4: Добавление Shard 1 в кластер
echo ""
echo "[4/7] Adding Shard 1 to cluster..."
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1/shard1:27018");
EOF
echo "✓ Shard 1 added to cluster"

# Шаг 5: Добавление Shard 2 в кластер
echo ""
echo "[5/7] Adding Shard 2 to cluster..."
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard2/shard2:27019");
EOF
echo "✅ Shard 2 added to cluster"

# Шаг 6: Включение шардирования для базы данных и коллекции
echo ""
echo "[6/7] Enabling sharding for database 'somedb' and collection 'helloDoc'..."
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name": "hashed" });
EOF
echo "✓ Sharding enabled for somedb.helloDoc"

# Шаг 7: Наполнение коллекции данными
echo "[7/7] Populating collection with 1000 documents..."
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
use somedb
for(var i = 0; i < 1000; i++) {
  db.helloDoc.insert({age: i, name: "ly" + i});
}
print("Total documents inserted: " + db.helloDoc.countDocuments());
EOF
echo "✓ Collection populated with data"

# Проверка состояния
echo ""
echo "========================================="
echo "Sharding Status"
echo "========================================="
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.status();
EOF

# Проверка распределения данных
echo ""
echo "========================================="
echo "Data Distribution"
echo "========================================="
echo ""
echo "Documents in Shard 1:"
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments();
EOF
echo ""
echo "Documents in Shard 2:"
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments();
EOF

echo ""
echo "========================================="
echo "✓ MongoDB Sharding initialization complete!"
echo "========================================="
echo ""
echo "You can now access the application at: http://localhost:8080"
echo "API documentation available at: http://localhost:8080/docs"
echo ""

