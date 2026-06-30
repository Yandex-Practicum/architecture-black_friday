#!/usr/bin/env bash

set -e

echo "Останавливаем и удаляем все контейнеры..."
docker ps -aq | xargs -r docker rm -f
docker compose down -v 2>/dev/null || true

wait_mongo() {
  service="$1"
  echo "Ждём $service..."
  for i in $(seq 1 60); do
    if docker compose exec -T "$service" \
        mongosh --host 127.0.0.1 --port 27017 --quiet \
        --eval 'quit(db.adminCommand({ ping: 1 }).ok ? 0 : 1)' \
        >/dev/null 2>&1
    then
      echo "$service запущен"
      return
    fi
    sleep 1
  done
  echo "$service не запустился"
  docker compose logs --tail=100 "$service"
  exit 1
}

wait_primary() {
  service="$1"
  echo "Ждём PRIMARY у $service..."
  for i in $(seq 1 60); do
    if docker compose exec -T "$service" \
        mongosh --host 127.0.0.1 --port 27017 --quiet \
        --eval 'quit(db.hello().isWritablePrimary ? 0 : 1)' \
        >/dev/null 2>&1
    then
      echo "$service стал PRIMARY"
      return
    fi
    sleep 1
  done
  echo "$service не стал PRIMARY"
  docker compose logs --tail=100 "$service"
  exit 1
}

echo "Запускаем config server..."
docker compose up -d configsvr

wait_mongo configsvr

echo "Инициализируем config server..."
docker compose exec -T configsvr \
  mongosh --host 127.0.0.1 --port 27017 --quiet --eval '
    try {
      rs.status();
      print("configReplSet уже инициализирован");
    } catch (error) {
      printjson(
        rs.initiate({
          _id: "configReplSet",
          configsvr: true,
          members: [
            { _id: 0, host: "configsvr:27017" }
          ]
        })
      );
    }
  '

wait_primary configsvr

echo "Запускаем шарды..."
docker compose up -d shard1 shard2

wait_mongo shard1
wait_mongo shard2

echo "Инициализируем первый шард..."
docker compose exec -T shard1 \
  mongosh --host 127.0.0.1 --port 27017 --quiet --eval '
    try {
      rs.status();
      print("shard1ReplSet уже инициализирован");
    } catch (error) {
      printjson(
        rs.initiate({
          _id: "shard1ReplSet",
          members: [
            { _id: 0, host: "shard1:27017" }
          ]
        })
      );
    }
  '

echo "Инициализируем второй шард..."
docker compose exec -T shard2 \
  mongosh --host 127.0.0.1 --port 27017 --quiet --eval '
    try {
      rs.status();
      print("shard2ReplSet уже инициализирован");
    } catch (error) {
      printjson(
        rs.initiate({
          _id: "shard2ReplSet",
          members: [
            { _id: 0, host: "shard2:27017" }
          ]
        })
      );
    }
  '

wait_primary shard1
wait_primary shard2

echo "Запускаем mongos..."
docker compose up -d mongos

wait_mongo mongos

echo "Добавляем шарды и настраиваем коллекцию..."
docker compose exec -T mongos \
  mongosh --host 127.0.0.1 --port 27017 --quiet \
  --eval '
    var adminDb = db.getSiblingDB("admin");
    var configDb = db.getSiblingDB("config");
    var shards = adminDb.runCommand({ listShards: 1 }).shards;
    var shardIds = shards.map(function(s) { return s._id.toString(); });
    if (shardIds.indexOf("shard1ReplSet") === -1) { sh.addShard("shard1ReplSet/shard1:27017"); }
    if (shardIds.indexOf("shard2ReplSet") === -1) { sh.addShard("shard2ReplSet/shard2:27017"); }
    var database = db.getSiblingDB("somedb");
    var namespace = "somedb.helloDoc";
    database.helloDoc.createIndex({ age: 1 });
    var collMeta = configDb.collections.findOne({ _id: namespace });
    if (!collMeta) {
      sh.enableSharding("somedb", "shard1ReplSet");
      sh.shardCollection(namespace, { age: 1 });
      sh.splitAt(namespace, { age: 500 });
      sh.moveChunk(namespace, { age: 750 }, "shard2ReplSet");
    }
    var ops = [];
    for (var i = 0; i < 1000; i++) {
      ops.push({ updateOne: { filter: { age: i }, update: { $set: { age: i, name: "ly" + i } }, upsert: true } });
    }
    database.helloDoc.bulkWrite(ops, { ordered: false });
    print("Total: " + database.helloDoc.countDocuments({}));
    database.helloDoc.aggregate([
      { $collStats: { count: {} } },
      { $project: { _id: 0, shard: 1, count: 1 } },
      { $sort: { shard: 1 } }
    ]).forEach(printjson);
  '

echo "Запускаем приложение..."
docker compose up -d --build pymongo_api

echo ""
echo "Готово"
echo "API: http://localhost:8080"
echo "Количество: http://localhost:8080/helloDoc/count"

