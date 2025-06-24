sh.addShard( "shard-1/shard1:27018");
sh.addShard( "shard-2/shard2:27019");

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
