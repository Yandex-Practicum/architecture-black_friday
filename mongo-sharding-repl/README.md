## Запуск кластера

```bash
docker-compose -f compose-mongo-sharding-repl.yaml up -d
```

## Инициализация шардинга и репликации

### 1. Инициализация сервера конфигурации

```bash
docker exec -it configSrv mongosh --port 27017
```

```javascript
rs.initiate(
  {
    _id : "config_server",
    configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" }
    ]
  }
);
exit();
```

### 2. Инициализация первого шарда

```bash
docker exec -it shard1_r1 mongosh --port 27018
```

```javascript
rs.initiate(
    {
      _id : "shard1",
      members: [
        { _id : 0, host : "shard1_r1:27018" },
        { _id : 1, host : "shard1_r2:27019" },
        { _id : 2, host : "shard1_r3:27020" }
      ]
    }
);
exit();
```

### 3. Инициализация второго шарда

```bash
docker exec -it shard2_r1 mongosh --port 27021
```

```javascript
rs.initiate(
    {
      _id : "shard2",
      members: [
        { _id : 0, host : "shard2_r1:27021" },
        { _id : 1, host : "shard2_r2:27022" },
        { _id : 2, host : "shard2_r3:27023" }
      ]
    }
);
exit();
```

### 4. Настройка роутера и добавление шардов

```bash
docker exec -it mongos_router mongosh --port 27024
```

```javascript
// Добавляем шарды в кластер
sh.addShard("shard1/shard1_r1:27018,shard1_r2:27019,shard1_r3:27020");
sh.addShard("shard2/shard2_r1:27021,shard2_r2:27022,shard2_r3:27023");

// Включаем шардирование для базы данных
sh.enableSharding("somedb");

// Настраиваем шардирование коллекции по полю name
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" });

// Переключаемся на базу данных
use somedb;

// Добавляем тестовые данные
for(var i = 0; i < 1000; i++) db.helloDoc.insert({age:i, name:"ly"+i});

// Проверяем общее количество документов
db.helloDoc.countDocuments();
exit();
```

## Проверка работы шардинга

### Проверка общего количества документов через роутер

```bash
# Проверка статуса шардинга
docker exec -it mongos_router mongosh --port 27024 --eval 'sh.status()'

# Проверка общего количества документов
docker exec -it mongos_router mongosh --port 27024 --eval 'use somedb; db.helloDoc.countDocuments()'

# Проверка количества документов в каждом шарде
docker exec -it shard1_r1 mongosh --port 27018 --eval 'use somedb; db.helloDoc.countDocuments()'
docker exec -it shard2_r1 mongosh --port 27021 --eval 'use somedb; db.helloDoc.countDocuments()'
```
