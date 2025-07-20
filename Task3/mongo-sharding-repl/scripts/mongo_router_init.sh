#!/usr/bin/env bash

mongosh --host router --port 27017 --eval '
  sh.addShard( "shard-1/shard-1-1:27017,shard-1-2:27017,shard-1-3:27017");
  sh.addShard( "shard-2/shard-2-1:27017,shard-2-2:27017,shard-2-3:27017");
  sh.enableSharding("somedb");
  sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } );

  db = db.getSiblingDB("somedb");
  for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i});
  db.helloDoc.countDocuments();
'
