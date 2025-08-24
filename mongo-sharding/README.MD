## Запустить контейнеры
```bash
docker-compose up -d
```

## Инициализировать replica set
```bash
docker cp scripts/init-config-replica.js configmongo:/tmp/
docker exec -it configmongo mongosh --port 27019 --file /tmp/init-config-replica.js
```

## Проверить статус
```bash
docker exec -it configmongo mongosh --port 27019 --eval "rs.status()"
```

## Инициализируем шарды
```bash
docker cp scripts/init-config-shard1.js shard1:/tmp/
docker cp scripts/init-config-shard2.js shard2:/tmp/

docker exec -it shard1 mongosh --port 27018 --file /tmp/init-config-shard1.js
docker exec -it shard2 mongosh --port 27020 --file /tmp/init-config-shard2.js
```

## Проверить статус
```bash
docker exec -it shard1 mongosh --port 27018 --eval "rs.status()"
docker exec -it shard2 mongosh --port 27020 --eval "rs.status()"
```

## Подключаемся к mongorouter и добавляем шарды
```bash
docker exec -it mongorouter mongosh --port 27017
```

```shell
sh.addShard("shard1ReplSet/shard1:27018")
sh.addShard("shard2ReplSet/shard2:27020")
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { _id: "hashed" })

sh.status()

use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
```

## Проверим данные

Если не подключены, то
```bash
docker exec -it mongorouter mongosh --port 27017
```

```shell
use somedb
db.helloDoc.countDocuments()
```

## Остановка и удаление данных

```bash
docker compose down -v
```