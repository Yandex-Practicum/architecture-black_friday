sh.addShard("shard1/shard1:27011");
sh.addShard("shard2/shard2:27012");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" });
use somedb;
for(var i = 0; i < 1000; i++) { db.helloDoc.insert({age:i, name:"ly"+i}); }