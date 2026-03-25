#!/usr/bin/env bash

set -e

echo "Init config server replica set"

docker compose exec -it configSrv mongosh --port 27017 --quiet <<'EOF'

rs.initiate({ _id: "config_server", configsvr: true, members: [ {_id: 0, host: "configSrv:27017"}]})

EOF

echo "Init shard1 replica set"

docker compose exec -it shard1 mongosh --port 27018 --quiet <<'EOF'

rs.initiate({ _id: "shard1", members: [{_id: 0, host: "shard1:27018"}]})

EOF

echo  "Init shard2 replica set"

docker compose exec -it shard2 mongosh --port 27019 --quiet <<'EOF'

rs.initiate({ _id: "shard2", members: [{_id: 1, host: "shard2:27019"}]})
EOF
echo "Wait a bit replica has is ready"
sleep 10

echo "Add shards and enable sharding"

docker compose exec -it mongo_router  mongosh --port 27020 --quiet <<'EOF'

sh.addShard( "shard1/shard1:27018");
sh.addShard( "shard2/shard2:27019");

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )
sh.status()
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insert({age:i, name:"ly"+i})
db.helloDoc.countDocuments()
EOF

docker compose exec -it shard1 mongosh --port 27018 --quiet <<'EOF'
use somedb
print("Shard1 documents: " + db.helloDoc.countDocuments())
EOF

echo "Count documents on shard2"

docker compose exec -it shard2 mongosh --port 27019 --quiet <<'EOF'
use somedb
print("Shard2 documents: " + db.helloDoc.countDocuments())
EOF

echo "Done."
read -p "Нажми Enter для закрытия..."

