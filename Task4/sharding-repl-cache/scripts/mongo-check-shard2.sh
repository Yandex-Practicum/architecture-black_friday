#!/usr/bin/env bash

docker exec -it shard-2-1 mongosh --port 27017 --eval '
  db = db.getSiblingDB("somedb");
  var count = db.helloDoc.countDocuments();
  print("Количество документов в shard-2-1: " + count);
'

docker exec -it shard-2-2 mongosh --port 27017 --eval '
  db = db.getSiblingDB("somedb");
  var count = db.helloDoc.countDocuments();
  print("Количество документов в shard-2-2: " + count);
'

docker exec -it shard-2-3 mongosh --port 27017 --eval '
  db = db.getSiblingDB("somedb");
  var count = db.helloDoc.countDocuments();
  print("Количество документов в shard-2-3: " + count);
'

docker exec -it shard-2-1 mongosh --port 27017 --eval '
rs.status()'
