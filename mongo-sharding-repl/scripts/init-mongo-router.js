sh.addShard("shard1ReplSet/shard1_node1:27017");
sh.addShard("shard2ReplSet/shard2_node1:27017");

sleep(5000);

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } );

var somedb = db.getSiblingDB("somedb");

var documentsToInsert = [];

for (var i = 0; i < 1000; i++) {
    documentsToInsert.push({age:i, name:"ly"+i});
}

somedb.helloDoc.insertMany(documentsToInsert);

somedb.helloDoc.countDocuments();
