#!/bin/bash

###
# Наполнение БД через mongos
# - БД: somedb
# - Коллекция: helloDoc
# - Кол-во документов: 1000
###

set -euo pipefail

docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
for (var i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({age: i, name: "ly" + i})
}
print("Inserted documents: " + db.helloDoc.countDocuments())

// Для быстрой проверки распределения по шардам (выводит сводку):
db.helloDoc.getShardDistribution()
EOF
