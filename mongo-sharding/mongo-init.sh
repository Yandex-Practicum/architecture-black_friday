#!/bin/bash


docker exec -i config-srv mongosh --port 27017 <<EOF
rs.initiate(
  {
    _id : "config-server",
       configsvr: true,
    members: [
      { _id : 0, host : "config-srv:27017" }
    ]
  }
);
exit()
EOF

sleep 1

docker exec -i shard-1 mongosh --port 27018 <<EOF
rs.initiate(
    {
      _id : "shard-1",
      members: [
        { _id : 0, host : "shard-1:27018" },
      ]
    }
);
exit()
EOF

sleep 1

docker exec -i shard-2 mongosh --port 27019 <<EOF
rs.initiate(
    {
      _id : "shard-2",
      members: [
        { _id : 1, host : "shard-2:27019" }
      ]
    }
);
exit()
EOF

sleep 1

# until docker exec -T mongos-router mongosh --port 27020 --eval 'db.runCommand({ping: 1})'; do
#   echo "Waiting for mongos-router..."
#   sleep 10
# done

docker exec -it mongos-router mongosh --port 27020<<EOF
sh.addShard( "shard-1/shard-1:27018");
sh.addShard( "shard-2/shard-2:27019");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" });
use somedb;
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i});
EOF