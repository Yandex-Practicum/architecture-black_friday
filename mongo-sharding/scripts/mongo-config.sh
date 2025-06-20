echo 'waiting configSrv...'
until mongosh --host configSrv:27017 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done 
mongosh --host configSrv:27017 --eval '
rs.initiate({
    _id: "config_server",
    configsvr: true,
    members: [{ _id: 0, host: "configSrv:27017" }]
})'

echo 'waiting shard1...'
until mongosh --host shard1:27018 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done
mongosh --host shard1:27018 --eval '
rs.initiate({
    _id: "shard1",
    members: [{ _id: 0, host: "shard1:27018" }]
})'

echo 'waiting shard2...'
until mongosh --host shard2:27019 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done
mongosh --host shard2:27019 --eval '
rs.initiate({
    _id: "shard2",
    members: [{ _id: 0, host: "shard2:27019" }]
})'

echo 'waiting router...'
until mongosh --host mongos_router:27020 --eval 'db.adminCommand("ping")' | grep 'ok'; do sleep 2; done
mongosh --host mongos_router:27020 --eval '
sh.addShard("shard1/shard1:27018");
sh.addShard("shard2/shard2:27019");
sh.enableSharding("somedb");
db = db.getSiblingDB("somedb");
db.helloDoc.createIndex({ name: "hashed" });
sh.shardCollection("somedb.helloDoc", { name: "hashed" });
'

echo 'Cluster configuration complete.'
