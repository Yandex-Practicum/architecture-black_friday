# Инициализируем сервис конфигурации (configSrv)
docker exec -t configSrv mongosh --port 27017 --eval '
rs.initiate(
  {
    _id: "config_rs",
    configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" },
    ]
  }
)
'

# Теперь инициализируем шарды
docker exec -t shard1R1 mongosh --port 27017 --eval '
rs.initiate(
  {
    _id: "shard1_rs",
    members: [
      { _id : 0, host : "shard1R1:27017" },
      { _id : 1, host : "shard1R2:27017" },
      { _id : 2, host : "shard1R3:27017" }
    ]
  }
)
'
docker exec -t shard2R1 mongosh --port 27017 --eval '
rs.initiate(
  {
    _id: "shard2_rs",
    members: [
      { _id : 0, host : "shard2R1:27017" },
      { _id : 1, host : "shard2R2:27017" },
      { _id : 2, host : "shard2R3:27017" }
    ]
  }
)
'

# Инициализируем роутер
docker exec -t mongos_router mongosh --port 27017 --eval '
  sh.addShard("shard1_rs/shard1R1:27017,shard1R2:27017,shard1R3:27017")
  sh.addShard("shard2_rs/shard2R1:27017,shard2R2:27017,shard2R3:27017")
  sh.enableSharding("somedb");
  sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } );
'