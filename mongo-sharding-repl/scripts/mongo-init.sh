#!/bin/bash
set -e

# Инициализируем базу данными через mongos
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
use somedb
for (let i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({ age: i, name: "ly" + i })
}
print("Inserted documents:", db.helloDoc.countDocuments())
EOF
