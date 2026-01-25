Инструкция для настройки шардирования Mongodb1
#################################
# Запустить контейнеры конфигурационный сервер MongoDb (configSvr), shard1, shard2
#################################
docker compose up -d configSvr shard1 shard2

#################################
# Инициализировать ноды MongoDB кластера
#################################
1. docker compose exec -T <container_name> mongosh --port <container_port> --quiet
2. rs.initiate(
  {
    _id : "{container_name}",
       configsvr: true,
    members: [
      { _id : 0, host : "{container_name}:{container_port}" }
    ]
  }
);
3. exit()

#################################
# Запустить контейнер mongos_роутер(mongodb1)
################################# 
docker compose up -d mongodb1
   
#################################
# Запустить контейнер mongos_роутер(mongodb1), cоздать и подключить шарды
#################################
docker compose exec -T <container_name> mongosh --port <container_port> --quiet

const dbName = "somedb";
const collName = "helloDoc";
const ns = `${dbName}.${collName}`;

const shards = db.getSiblingDB("config").shards.find().toArray().map(s => s._id);

if (!shards.includes("shard1")) {
  sh.addShard("shard1/shard1:27018");
  print("Shard1 added");
}

if (!shards.includes("shard2")) {
  sh.addShard("shard2/shard2:27020");
  print("Shard2 added");
}

#################################
# Включить режим шардирования 
#################################
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
# Определить тип шардирования 
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
  print(`Collection ${ns} sharded`);
} else {
  print(`Collection ${ns} already sharded`);
}
EOF