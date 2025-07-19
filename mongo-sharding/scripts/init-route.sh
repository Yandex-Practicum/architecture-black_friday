#!/bin/bash

###
#Инцициализируйте роутер и наполните его тестовыми данными
###

docker compose exec -T mongos_router mongosh --port 27020 <<EOF
sh.addShard( "shard1/shard1:27018");
sh.addShard( "shard2/shard2:27019");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insert({age:i, name:"ly"+i})
var count = db.helloDoc.countDocuments();
print("Количество документов: " + count);
EOF

echo "Скрипт выполнен. Результаты выше."
read -p "Нажмите Enter, чтобы выйти..." DUMMY