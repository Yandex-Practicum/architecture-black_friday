Инструкция для настройки шардирования MongoDB с репликацией и кешированием
#################################
# Шаг 1: Запустить контейнеры Config Server Replica Set
#################################
docker compose up -d configSvr configSvr-replica2 configSvr-replica3

#################################
# Шаг 2: Инициализировать Config Server Replica Set
#################################
docker compose exec -T configSvr mongosh --port 27019 --quiet

rs.initiate(
  {
    _id : "configReplSet",
    configsvr: true,
    members: [
      { _id : 0, host : "configSvr:27019" },
      { _id : 1, host : "configSvr-replica2:27119" },
      { _id : 2, host : "configSvr-replica3:27219" }
    ]
  }
);

exit

# Подождать ~15-20 секунд для инициализации replica set

#################################
# Шаг 3: Запустить контейнеры Shard1 Replica Set
#################################
docker compose up -d shard1 shard1-replica2 shard1-replica3

#################################
# Шаг 4: Инициализировать Shard1 Replica Set
#################################
docker compose exec -T shard1 mongosh --port 27018 --quiet

rs.initiate(
  {
    _id : "shard1ReplSet",
    members: [
      { _id : 0, host : "shard1:27018" },
      { _id : 1, host : "shard1-replica2:27118" },
      { _id : 2, host : "shard1-replica3:27218" }
    ]
  }
);

exit

# Подождать ~15-20 секунд для инициализации replica set

#################################
# Шаг 5: Запустить контейнеры Shard2 Replica Set
#################################
docker compose up -d shard2 shard2-replica2 shard2-replica3

#################################
# Шаг 6: Инициализировать Shard2 Replica Set
#################################
docker compose exec -T shard2 mongosh --port 27020 --quiet

rs.initiate(
  {
    _id : "shard2ReplSet",
    members: [
      { _id : 0, host : "shard2:27020" },
      { _id : 1, host : "shard2-replica2:27120" },
      { _id : 2, host : "shard2-replica3:27220" }
    ]
  }
);

exit

# Подождать ~15-20 секунд для инициализации replica set

#################################
# Шаг 7: Проверить статус replica sets (опционально)
#################################
# Проверка Config Server
docker compose exec -T configSvr mongosh --port 27019 --quiet --eval "rs.status()"

# Проверка Shard1
docker compose exec -T shard1 mongosh --port 27018 --quiet --eval "rs.status()"

# Проверка Shard2
docker compose exec -T shard2 mongosh --port 27020 --quiet --eval "rs.status()"

#################################
# Шаг 8: Запустить контейнер mongos роутер (mongodb1)
################################# 
docker compose up -d mongodb1

# Подождать ~10 секунд для запуска mongos

#################################
# Шаг 9: Подключить шарды к кластеру
#################################
docker compose exec -T mongodb1 mongosh --port 27017 --quiet

const shards = db.getSiblingDB("config").shards.find().toArray().map(s => s._id);

if (!shards.includes("shard1ReplSet")) {
  sh.addShard("shard1ReplSet/shard1:27018,shard1-replica2:27118,shard1-replica3:27218");
  print("Shard1 replica set added");
} else {
  print("Shard1 already exists");
}

if (!shards.includes("shard2ReplSet")) {
  sh.addShard("shard2ReplSet/shard2:27020,shard2-replica2:27120,shard2-replica3:27220");
  print("Shard2 replica set added");
} else {
  print("Shard2 already exists");
}

#################################
# Шаг 10: Включить режим шардирования для базы данных
#################################
const dbName = "somedb";
const collName = "helloDoc";
const ns = `${dbName}.${collName}`;

const dbInfo = db.getSiblingDB("config")
  .databases
  .findOne({ _id: dbName });

if (!dbInfo || !dbInfo.partitioned) {
  sh.enableSharding(dbName);
  print(`Sharding enabled for database ${dbName}`);
} else {
  print(`Database ${dbName} already sharded`);
}

#################################
# Шаг 11: Создать и шардировать коллекцию
#################################
const appDb = db.getSiblingDB(dbName);
if (!appDb.getCollectionNames().includes(collName)) {
  appDb.createCollection(collName);
  print(`Collection ${collName} created`);
}

const collInfo = db.getSiblingDB("config")
  .collections
  .findOne({ _id: ns });

if (!collInfo) {
  sh.shardCollection(ns, { name: "hashed" });
  print(`Collection ${ns} sharded with hashed key on 'name' field`);
} else {
  print(`Collection ${ns} already sharded`);
}

#################################
# Шаг 12: Проверить статус шардированного кластера
#################################
sh.status();

exit

#################################
# Шаг 13: Заполняем mongodb данными
#################################

```shell
./scripts/mongo-init.sh
```

#################################
# Шаг 14: Запустить Redis для кеширования
#################################
docker compose up -d redis

# Подождать ~5 секунд для запуска Redis

#################################
# Шаг 15: Проверить работу Redis (опционально)
#################################
docker compose exec -T redis redis-cli ping
# Ожидаемый ответ: PONG

# Проверить конфигурацию Redis
docker compose exec -T redis redis-cli INFO memory

#################################
# Шаг 16: Запустить API приложение
#################################
docker compose up -d pymongo_api

Откройте в браузере http://localhost:8080

## Доступные эндпоинты
Список доступных эндпоинтов, swagger http://<ip виртуальной машины>:8080/docs