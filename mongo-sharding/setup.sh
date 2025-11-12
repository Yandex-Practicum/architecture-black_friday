# Инициализируем сервис конфигурации (configSrv)
docker exec -t configSrv mongosh --port 27017 --eval '
rs.initiate(
  {
    _id : "config_server",
       configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" }
    ]
  }
)
'

# Теперь инициализируем шарды
docker exec -t shard1 mongosh --port 27018 --eval '
rs.initiate(
    {
      _id : "shard1",
      members: [
        { _id : 0, host : "shard1:27018" }
      ]
    }
)
'

docker exec -t shard2 mongosh --port 27019 --eval '
rs.initiate(
    {
      _id : "shard2",
      members: [
        { _id : 1, host : "shard2:27019" }
      ]
    }
  )
 '

# Инициализируем роутер
docker exec -t mongos_router mongosh --port 27020 --eval '
  sh.addShard("shard1/shard1:27018");
  sh.addShard("shard2/shard2:27019");
  sh.enableSharding("somedb");
  sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } );
'