#!/bin/bash

echo "Ожидание готовности configSrv"
until docker compose exec -T configSrv mongosh --port 27017 --eval "db.adminCommand('ping')" &>/dev/null; do
  sleep 1
done

echo "Инициализация configSrv "
docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate({ _id: "config_server", configsvr: true, members: 
    [{ _id: 0, host: "configSrv:27017" }] 
});
EOF

# Функция ожидания готовности узла
wait_for_node() {
  local node=$1
  local port=$2
  echo "Ожидание готовности  $node (port $port)"
  until docker compose exec -T $node mongosh --port $port --eval "db.adminCommand('ping')" &>/dev/null; do
    sleep 1
  done
}

# Ожидание всех узлов shard1
wait_for_node shard1-1 27018
wait_for_node shard1-2 27028
wait_for_node shard1-3 27038

echo "Инициализация репликасета shard1"
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.initiate({_id: "shard1", members: [
      { _id: 0, host: "shard1-1:27018" },
      { _id: 1, host: "shard1-2:27028" },
      { _id: 2, host: "shard1-3:27038" }
    ]
});
EOF

# Ожидание всех узлов shard2
wait_for_node shard2-1 27019
wait_for_node shard2-2 27029
wait_for_node shard2-3 27039

echo "Инициализация репликасета shard2"
docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
rs.initiate({ _id: "shard2", members: [
      { _id: 0, host: "shard2-1:27019" },
      { _id: 1, host: "shard2-2:27029" },
      { _id: 2, host: "shard2-3:27039" }
    ]
});

EOF

# Ожидание выбора PRIMARY
echo "Ожидание выбора PRIMARY"
sleep 20

echo "Ожидание готовности mongos_router"
until docker compose exec -T mongos_router mongosh --port 27020 --eval "db.adminCommand('ping')" &>/dev/null; do
  sleep 1
done

echo "Добавление шардов в роутер"
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1/shard1-1:27018");
sh.addShard("shard2/shard2-1:27019");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name": "hashed" });

use somedb
for (var i = 0; i < 1000; i++) db.helloDoc.insert({ age: i, name: "ly" + i });
db.helloDoc.countDocuments();
EOF
