Переходим в папку sharding-repl-cache

## Диаграммы
[Diagram/task5.drawio](Diagram/task5.drawio)

## Запустить контейнеры
```bash
cd sharding-repl-cache
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
docker cp scripts/init-config-shard1.js shard1-primary:/tmp/
docker cp scripts/init-config-shard2.js shard2-primary:/tmp/

docker exec -it shard1-primary mongosh --port 27018 --file /tmp/init-config-shard1.js
docker exec -it shard2-primary mongosh --port 27023 --file /tmp/init-config-shard2.js
```

## Проверить статус
```bash
docker exec -it shard1-primary mongosh --port 27018 --eval "rs.status()"
docker exec -it shard2-primary mongosh --port 27023 --eval "rs.status()"
```

## Подключаемся к mongorouter и добавляем шарды
```bash
docker exec -it mongorouter mongosh --port 27017
```

```shell
sh.addShard("shard1ReplSet/shard1-primary:27018,shard1-secondary1:27021,shard1-secondary2:27022")
sh.addShard("shard2ReplSet/shard2-primary:27023,shard2-secondary1:27024,shard2-secondary2:27025")
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