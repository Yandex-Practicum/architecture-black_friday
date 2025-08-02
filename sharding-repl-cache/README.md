
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
docker exec -it shard-1-primary mongosh --port 27018
```

```bash
rs.initiate(
    {
      _id : "shard-1",
      members: [
        { _id: 0, host: "shard-1-primary:27018"},
        { _id: 1, host: "shard-1-replica-1:27018"},
        { _id: 2, host: "shard-1-replica-2:27018"}
      ]
    }
);
```

```bash
exit()
```

```bash
docker exec -it shard-2-primary mongosh --port 27019
```

```bash
rs.initiate(
    {
      _id : "shard-2",
      members: [
        { _id: 0, host: "shard-2-primary:27019" },
        { _id: 1, host: "shard-2-replica-1:27019" },
        { _id: 2, host: "shard-2-replica-2:27019" }
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
sh.addShard("shard-1/shard-1-primary:27018,shard-1-replica-1:27018,shard-1-replica-2:27018");
```
```bash
sh.addShard("shard-2/shard-2-primary:27019,shard-2-replica-1:27019,shard-2-replica-2:27019");
```

```bash
sh.enableSharding("somedb");
```
```bash
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" })
```

```bash
use somedb;
```
```bash
for(var i = 0; i < 2000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i});
```
