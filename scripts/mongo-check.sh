#!/bin/bash

printf "\n\e[32m Total records: \e[0m\n"

docker compose exec -T mongos-router mongosh --port 27017 --quiet <<EOF
use somedb

db.helloDoc.countDocuments({}) 
exit();
EOF

printf "\n\e[32m Shard1 records: \e[0m\n"

docker compose exec -T shard1-1 mongosh --port 27020 --quiet <<EOF
use somedb

db.helloDoc.countDocuments() 
exit();
EOF

printf "\n\e[32m Shard1 replicas count: \e[0m\n"

docker compose exec -T shard1-1 mongosh --port 27020 --quiet <<EOF
db.adminCommand( { replSetGetStatus: 1 } ).members.length
exit();
EOF

printf "\n\e[32m Shard2 records: \e[0m\n"

docker compose exec -T shard2-1 mongosh --port 27030 --quiet <<EOF
use somedb

db.helloDoc.countDocuments() 
exit();
EOF

printf "\n\e[32m Shard2 replicas count: \e[0m\n"

docker compose exec -T shard2-1 mongosh --port 27030 --quiet <<EOF
db.adminCommand( { replSetGetStatus: 1 } ).members.length
exit();
EOF


printf "\r"