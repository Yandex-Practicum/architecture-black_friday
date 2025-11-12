docker exec -t shard1R1 mongosh --port 27017 --eval 'print("Количество документов в shard1: " + db.helloDoc.countDocuments())' somedb
docker exec -t shard2R1 mongosh --port 27017 --eval 'print("Количество документов в shard2: " + db.helloDoc.countDocuments())' somedb
docker exec -t mongos_router mongosh --port 27017 --eval 'print("Всего: " + db.helloDoc.countDocuments())' somedb