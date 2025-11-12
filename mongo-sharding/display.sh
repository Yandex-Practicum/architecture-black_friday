# Первый шард
docker exec -t shard1 mongosh --port 27018 --eval 'print("Количество документов в shard1: " + db.helloDoc.countDocuments())' somedb

# Второй шард
docker exec -t shard2 mongosh --port 27019 --eval 'print("Количество документов в shard2: " + db.helloDoc.countDocuments())' somedb

# Всего
docker exec -t mongos_router mongosh --port 27020 --eval 'print("Всего: " + db.helloDoc.countDocuments())' somedb