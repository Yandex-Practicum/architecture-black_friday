# mongo_sharding_repl

## Как запустить

Запускаем приложение и mongodb с шардами и репликами

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

Посмотреть количество документов на каждом шарде

```shell
chmod +x ./scripts/documents_status.sh
./scripts/documents_status.sh
```


## Проверка отказоустойчивости

Остановить PRIMARY шард
```shell
docker stop shard1_primary
```

Проверить, что выбрался новый шард
```shell
docker exec shard1_secondary_1 mongosh --host shard1_secondary_1 --port 27018 --eval "rs.status().members.map(m => ({name: m.name, stateStr: m.stateStr}))"
```

Проверить, что данные доступны через mongos

```shell
docker exec mongos_router mongosh --host mongos_router --port 27020 --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"
```
