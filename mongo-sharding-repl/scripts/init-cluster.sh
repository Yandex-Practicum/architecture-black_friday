echo 'waiting for configSrv...'
until mongosh --host configSrv1:27017 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done 
until mongosh --host configSrv2:27017 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done 
until mongosh --host configSrv3:27017 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done 
mongosh --host configSrv1:27017 --eval '
rs.initiate({
    _id: "config_server",
    configsvr: true,
    members: [
        { _id: 0, host: "configSrv1:27017" },
        { _id: 1, host: "configSrv2:27017" },
        { _id: 2, host: "configSrv3:27017" }
    ]
})'

# ---
echo 'waiting for shard1...'
until mongosh --host shard1-1:27018 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done
until mongosh --host shard1-2:27018 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done
until mongosh --host shard1-3:27018 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done
mongosh --host shard1-1:27018 --eval '
rs.initiate({
    _id: "shard1",
    members: [
        { _id: 0, host: "shard1-1:27018" },
        { _id: 1, host: "shard1-2:27018" },
        { _id: 2, host: "shard1-3:27018" }
    ]
})'

# ---
echo 'waiting for shard2...'
until mongosh --host shard2-1:27019 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done
until mongosh --host shard2-2:27019 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done
until mongosh --host shard2-3:27019 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done
mongosh --host shard2-1:27019 --eval '
rs.initiate({
    _id: "shard2",
    members: [
        { _id: 0, host: "shard2-1:27019" },
        { _id: 1, host: "shard2-2:27019" },
        { _id: 2, host: "shard2-3:27019" }
    ]
})'

# ---
echo 'waiting for mongos...'
until mongosh --host mongos_router-1:27020 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done
mongosh --host mongos_router-1:27020 --eval '
sh.addShard("shard1/shard1-1:27018,shard1-2:27018,shard1-3:27018");
sh.addShard("shard2/shard2-1:27019,shard2-2:27019,shard2-3:27019");

sh.enableSharding("somedb");
db = db.getSiblingDB("somedb");
db.helloDoc.createIndex({ name: "hashed" });
sh.shardCollection("somedb.helloDoc", { name: "hashed" });
'

# ---
echo 'Cluster initialization complete.'