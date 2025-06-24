docker cp init-mongo-config.js configSrv:/tmp/init-mongo-config.js
docker exec -it configSrv mongosh --port 27017 /tmp/init-mongo-config.js
timeout /t 10

docker cp init-mongo-shard.js shard1_node1:/tmp/init-mongo-shard.js
docker exec -it shard1_node1 mongosh --port 27017 /tmp/init-mongo-shard.js --eval "var shardName='shard1ReplSet'; var shardId=0; var primaryHostAndPort='shard1_node1:27017';"
docker cp init-mongo-shard.js shard2_node1:/tmp/init-mongo-shard.js
docker exec -it shard2_node1 mongosh --port 27017 /tmp/init-mongo-shard.js --eval "var shardName='shard2ReplSet'; var shardId=1; var primaryHostAndPort='shard2_node1:27017';"
timeout /t 10

docker cp init-mongo-router.js mongos_router:/tmp/init-mongo-router.js
docker exec -it mongos_router mongosh --port 27020 /tmp/init-mongo-router.js
