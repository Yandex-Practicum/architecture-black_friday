# mongo-sharding

## Как запустить

Запускаем приложение и mongodb с шардами

```shell
docker compose up -d
```

## Как запустить на локальной машине

Запустить скрипт
```shell
chmod +x ./scripts/init-cluster.sh
./scripts/init-cluster.sh
```

Заполнить базу данными

```shell
docker exec mongos_router mongosh --host mongos_router --port 27020 --quiet --eval '
db = db.getSiblingDB("somedb");
for (let i = 0; i < 1500; i++) {
  db.helloDoc.insertOne({
    name: "User" + i,
    age: 20 + (i % 80),
    user_id: i
  });
}
print("Inserted 1000 users");
db.helloDoc.countDocuments();
'
```
Посмотреть распределение

```shell
docker exec mongos_router mongosh --host mongos_router --port 27020 --eval "
db.getSiblingDB('somedb').helloDoc.getShardDistribution()
"
```
