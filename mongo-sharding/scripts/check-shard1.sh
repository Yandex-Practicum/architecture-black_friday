#!/bin/bash

###
#Проверьте документы на 1 шарде
###

docker compose exec -T shard1 mongosh --port 27018 <<EOF
use somedb;
var count = db.helloDoc.countDocuments();
print("Количество документов shard1: " + count);
EOF

echo "Скрипт выполнен. Результаты выше."
read -p "Нажмите Enter, чтобы выйти..." DUMMY