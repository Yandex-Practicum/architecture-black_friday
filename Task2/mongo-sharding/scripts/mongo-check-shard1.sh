#!/usr/bin/env bash

docker exec -it shard1 mongosh --port 27018 --eval '
  db = db.getSiblingDB("somedb");
  var count = db.helloDoc.countDocuments();
  print("Количество документов в shard1: " + count);
'
