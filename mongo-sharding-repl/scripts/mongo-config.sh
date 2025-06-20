echo 'waiting configSrv...'
until mongosh --host configSrvPrimary:27017 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done 
until mongosh --host configSrvSecondary1:27017 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done 
until mongosh --host configSrvSecondary2:27017 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done 
mongosh --host configSrvPrimary:27017 --eval '
rs.initiate({
    _id: "config_server",
    configsvr: true,
    members: [
        { _id: 0, host: "configSrvPrimary:27017" },
        { _id: 1, host: "configSrvSecondary1:27017" },
        { _id: 2, host: "configSrvSecondary2:27017" }
    ]
})'

echo 'waiting shard1...'
until mongosh --host shard1Primary:27018 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done
until mongosh --host shard1Secondary1:27018 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done
until mongosh --host shard1Secondary2:27018 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done
mongosh --host shard1Primary:27018 --eval '
rs.initiate({
    _id: "shard1",
    members: [
        { _id: 0, host: "shard1Primary:27018", priority: 3 },
        { _id: 1, host: "shard1Secondary1:27018", priority: 2 },
        { _id: 2, host: "shard1Secondary2:27018", priority: 1 }
    ]
})'

echo 'waiting shard2...'
until mongosh --host shard2Primary:27019 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done
until mongosh --host shard2Secondary1:27019 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done
until mongosh --host shard2Secondary2:27019 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done
mongosh --host shard2Primary:27019 --eval '
rs.initiate({
    _id: "shard2",
    members: [
        { _id: 0, host: "shard2Primary:27019", priority: 3 },
        { _id: 1, host: "shard2Secondary1:27019", priority: 2 },
        { _id: 2, host: "shard2Secondary2:27019", priority: 1 }
    ]
})'

echo 'waiting router...'
until mongosh --host mongos_router1:27020 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done
until mongosh --host mongos_router2:27020 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done
until mongosh --host mongos_router3:27020 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done
mongosh --host mongos_router1:27020 --eval '
sh.addShard("shard1/shard1Primary:27018,shard1Secondary1:27018,shard1Secondary2:27018");
sh.addShard("shard2/shard2Primary:27019,shard2Secondary1:27019,shard2Secondary2:27019");
sh.enableSharding("somedb");
db = db.getSiblingDB("somedb");
db.helloDoc.createIndex({ name: "hashed" });
sh.shardCollection("somedb.helloDoc", { name: "hashed" });
'

echo 'Cluster configuration complete.'
