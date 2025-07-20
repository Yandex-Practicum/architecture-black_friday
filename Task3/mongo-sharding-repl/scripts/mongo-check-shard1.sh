#!/usr/bin/env bash

docker exec -it shard-1-1 mongosh --port 27017 --eval '
  db = db.getSiblingDB("somedb");
  var count = db.helloDoc.countDocuments();
  print("Количество документов в shard-1-1: " + count);
'

docker exec -it shard-1-2 mongosh --port 27017 --eval '
  db = db.getSiblingDB("somedb");
  var count = db.helloDoc.countDocuments();
  print("Количество документов в shard-1-2: " + count);
'

docker exec -it shard-1-3 mongosh --port 27017 --eval '
  db = db.getSiblingDB("somedb");
  var count = db.helloDoc.countDocuments();
  print("Количество документов в shard-1-3: " + count);
'

docker exec -it shard-1-1 mongosh --port 27017 --eval '
rs.status()'
