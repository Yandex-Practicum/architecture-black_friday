
1. Перейти в директорию mongo-sharding-repl-cache и запустить docker compose up -d
#==================Когда поднимутся все контейнеры==================
2. Настроить сервер конфигурации:
    docker exec -it configSrv mongosh --port 27017
    > rs.initiate(
    {
        _id : "config_server",
        configsvr: true,
        members: [
        { _id : 0, host : "configSrv:27017" }
        ]
    }
    );
    > exit(); 
3. Настроить первый шард:
    docker exec -it mongodb1 mongosh --port 27018

    > rs.initiate({_id: "mongodb1", members: [
        {_id: 0, host: "mongodb1:27018"},
        {_id: 1, host: "mongodb1_r1:27023"},
        {_id: 2, host: "mongodb1_r2:27024"}
        ]});
    > exit();
4. Настроить второй шард:
    docker exec -it mongodb2 mongosh --port 27019

    > rs.initiate({_id: "mongodb2", members: [
        {_id: 0, host: "mongodb2:27019"},
        {_id: 1, host: "mongodb2_r1:27021"},
        {_id: 2, host: "mongodb2_r2:27022"}
        ]});
    > exit(); 
5. Настроить роутер, создать и наполнить БД:
    docker exec -it mongos_router mongosh --port 27020

    > sh.addShard("mongodb1/mongodb1:27018,mongodb1_r1:27023,mongodb1_r2:27024");
    > sh.addShard("mongodb2/mongodb2:27019,mongodb2_r1:27021,mongodb2_r2:27022");

    > sh.enableSharding("somedb");
    > sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )

    > use somedb
    > for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
    > exit(); 
