#!/usr/bin/env bash

mongosh --host mongos_router --port 27020 --eval '
  sh.addShard( "shard1/shard1:27018");
  sh.addShard( "shard2/shard2:27019");
  sh.enableSharding("somedb");
  sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } );

  db = db.getSiblingDB("somedb");
  for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i});
  db.helloDoc.countDocuments();
'
