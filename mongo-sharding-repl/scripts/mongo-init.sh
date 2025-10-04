#!/bin/bash

wait_for_mongo() {
    local container=$1
    local port=$2
    echo "Ждем $container на порту $port..."
    
    # Пытаемся выполнить простую команду пока не получится
    until docker compose exec -T $container mongosh --port $port --eval "db.adminCommand('ping')" >/dev/null 2>&1; do
        sleep 2
        echo "Все еще ждем $container..."
    done
    echo "$container готов!"
}

check_replica_set() {
    local container=$1
    local port=$2
    local rs_name=$3
    echo "Проверяем, инициализирован ли реплика-сет $rs_name в $container..."
    
    if docker compose exec -T $container mongosh --port $port --eval "rs.status().ok" --quiet 2>/dev/null | grep -q 1; then
        echo "Реплика-сет $rs_name уже инициализирован"
        return 0
    else
        echo "Реплика-сет $rs_name не инициализирован"
        return 1
    fi
}

echo "Настройка конфига"
wait_for_mongo configSrv-1 27019

if ! check_replica_set configSrv-1 27019 "configSrv"; then
  echo "Начали инициализацию"
  docker compose exec -T configSrv-1 mongosh --port 27019 <<EOF
  rs.initiate(
    {
      _id : "configSrv",
      configsvr: true,
      members: [
        { _id : 0, host : "configSrv-1:27019" },
        { _id : 1, host : "configSrv-2:27019" },
        { _id : 2, host : "configSrv-3:27019" }
      ]
    }
  );
EOF
fi

echo "Настройка Шарда 1"
wait_for_mongo shard1-1 27018

if ! check_replica_set shard1-1 27018 "shard1"; then
  echo "Начали инициализацию"
  docker compose exec -T shard1-1 mongosh --port 27018 <<EOF
  rs.initiate(
      {
        _id : "shard1",
        members: [
          { _id : 0, host : "shard1-1:27018" },
          { _id : 1, host : "shard1-2:27018" },
          { _id : 2, host : "shard1-3:27018" }
        ]
      }
  );
EOF
fi

echo "Настройка Шарда 2"
wait_for_mongo shard2-1 27018

if ! check_replica_set shard2-1 27018 "shard2"; then
  echo "Начали инициализацию"
  docker compose exec -T shard2-1 mongosh --port 27018 <<EOF
  rs.initiate(
      {
        _id : "shard2",
        members: [
          { _id : 0, host : "shard2-1:27018" },
          { _id : 1, host : "shard2-2:27018" },
          { _id : 2, host : "shard2-3:27018" }
        ]
      }
  );
EOF
fi

echo "Настройка Роутера"
wait_for_mongo mongosRouter 27017

docker compose exec -T mongosRouter mongosh --port 27017 <<EOF

var currentShards = sh.status().shards;
if (!currentShards || currentShards.length === 0) {
  print("Добавляем шарды"); 
  sh.addShard( "shard1/shard1-1:27018,shard1-2:27018,shard1-3:27018");
  sh.addShard( "shard2/shard2-1:27018,shard2-2:27018,shard2-3:27018");
} else {
  print("Шарды уже добавлены:");
  for (var i = 0; i < currentShards.length; i++) {
      print(" - " + currentShards[i]._id);
  }
}

var database = "somedb";
var existingDbs = sh.status().databases;
var dbExists = false;

for (var i = 0; i < existingDbs.length; i++) {
    if (existingDbs[i].database === database) {
        dbExists = true;
        break;
    }
}

if (!dbExists) {
    print("Включаем шардирование для базы " + database);
    sh.enableSharding(database);
} else {
    print("Шардирование для базы " + database + " уже включено");
}

var collection = database + ".helloDoc";
try {
    var collInfo = sh.getCollection(collection);
    print("Коллекция " + collection + " уже существует и шардирована");
} catch (e) {
    print("Шардируем коллекцию " + collection);
    sh.shardCollection(collection, { "name" : "hashed" });
}

use somedb
if (db.helloDoc.countDocuments() === 0) {
    print("Вставляем тестовые данные...");
    for(var i = 0; i < 1000; i++) {
        db.helloDoc.insert({age: i, name: "ly" + i});
    }
    print("Вставлено " + db.helloDoc.countDocuments() + " документов");
} else {
    print("Данные уже существуют: " + db.helloDoc.countDocuments() + " документов");
}

db.helloDoc.countDocuments() 
db.helloDoc.getShardDistribution()
exit();
EOF
