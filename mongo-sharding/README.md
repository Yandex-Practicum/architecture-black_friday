
## Шаги инициализации БД
#### 1. Запуск контейнеров
```bash
docker compose up -d --build
```
#### 2. Инициализация сервера конфигурации
```bash
docker exec -it config-srv mongosh --port 27017
```

```bash
rs.initiate(
  {
    _id : "config-server",
       configsvr: true,
    members: [
      { _id : 0, host : "config-srv:27017" }
    ]
  }
);
```

```bash
exit()
```

#### 3. Инициализация шардов
```bash
docker exec -it shard-1 mongosh --port 27018
```

```bash
rs.initiate(
    {
      _id : "shard-1",
      members: [
        { _id : 0, host : "shard-1:27018" },
      ]
    }
);
```

```bash
exit()
```

```bash
docker exec -it shard-2 mongosh --port 27019
```

```bash
rs.initiate(
    {
      _id : "shard-2",
      members: [
        { _id : 1, host : "shard-2:27019" }
      ]
    }
);
```

```bash
exit()
```
#### 4. Инициализация роутера

```bash
docker exec -it mongos-router mongosh --port 27020
```

```bash
sh.addShard( "shard-1/shard-1:27018");
sh.addShard( "shard-2/shard-2:27019");
```

```bash
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" })
```

```bash
use somedb;
for(var i = 0; i < 2000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i});
```
