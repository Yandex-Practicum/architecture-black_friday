#!/bin/bash

###
#Проверьте документы на 2 шарде
###

docker compose exec -T shard2 mongosh --port 27019 <<EOF
use somedb;
var count = db.helloDoc.countDocuments();
print("Количество документов shard1: " + count);
EOF

echo "Скрипт выполнен. Результаты выше."
read -p "Нажмите Enter, чтобы выйти..." DUMMY