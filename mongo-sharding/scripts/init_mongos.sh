#!/bin/bash
echo "===> Добавление шардов в Mongos и включение шардирования базы/коллекции"

docker exec -i mongos1 mongosh --quiet --port 27020 --eval '
sh.addShard("shard1/shard1:27018");
sh.addShard("shard2/shard2:27019");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name": "hashed" });
'

echo "===> Шарды и Mongos настроены"
