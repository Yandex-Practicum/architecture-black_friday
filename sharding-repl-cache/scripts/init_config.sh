#!/bin/bash
echo "===> Инициализация Config Servers"

docker exec -i configSrv1  mongosh --quiet --eval '
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv1:27017" },
    { _id: 1, host: "configSrv2:27017" },
    { _id: 2, host: "configSrv3:27017" }
  ]
});
'

echo "===> Config Servers инициализированы"

#------------------- init shards-------------------------------

echo "===> Инициализация реплика сетов (шардов)"

# --- Шард rs0: mongodb1, mongodb3, mongodb5 ---
docker exec -i mongodb1 mongosh --quiet --port 27018 --eval '
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongodb1:27018" }
  ]
});
'

# Подождем чтобы PRIMARY поднялся
sleep 5

docker exec -i mongodb1 mongosh --quiet --port 27018 --eval '
rs.add("mongodb3:27022")
rs.add("mongodb5:27024")
'

# --- Шард rs1: mongodb2, mongodb4, mongodb6 ---
docker exec -i mongodb2 mongosh --quiet --port 27019 --eval '
rs.initiate({
  _id: "rs1",
  members: [
    { _id: 0, host: "mongodb2:27019" }
  ]
});
'

sleep 5

docker exec -i mongodb2 mongosh --quiet --port 27019 --eval '
rs.add("mongodb4:27023")
rs.add("mongodb6:27025")
'

echo "===> Реплика сети инициализированы"

#------------------- init mongos-------------------------------

echo "===> Добавление шардов в Mongos и включение шардирования базы/коллекции"

# Подождем, пока реплика сеты синхронизируются
sleep 10

docker exec -i mongos1 mongosh --quiet --port 27020 --eval '
sh.addShard("rs0/mongodb1:27018")
sh.addShard("rs1/mongodb2:27019")
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { "name": "hashed" })
'

echo "===> Шарды и Mongos настроены"
