docker cp init-mongo-config.js configSrv:/tmp/init-mongo-config.js
docker exec -it configSrv mongosh --port 27017 /tmp/init-mongo-config.js
pause

docker cp init-mongo-shard.js shard1:/tmp/init-mongo-shard.js
docker exec -it shard1 mongosh --port 27018 /tmp/init-mongo-shard.js --eval "var shardName='shard-1'; var shardId=0; var primaryHostAndPort='shard1:27018';"
docker cp init-mongo-shard.js shard2:/tmp/init-mongo-shard.js
docker exec -it shard2 mongosh --port 27019 /tmp/init-mongo-shard.js --eval "var shardName='shard-2'; var shardId=1; var primaryHostAndPort='shard2:27019';"
pause

docker cp init-mongo-router.js mongos_router:/tmp/init-mongo-router.js
docker exec -it mongos_router mongosh --port 27020 /tmp/init-mongo-router.js
