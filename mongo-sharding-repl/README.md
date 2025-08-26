# Инициализация шардирования с репликацией

Этот проект реализует шардирование и репликацию MongoDB.  
Каждый шард — реплика-сет из 3 нод.

---

## 1. Запустите сервисы

```bash
docker compose up -d
```
Проверьте логи
```bash
docker compose logs -f pymongo_api
```

## 2. Инициализируйте config servers
```bash
docker compose exec -T configsvr1 mongosh --port 27019 --quiet "--eval" "rs.initiate({_id: 'configReplSet', configsvr: true, members: [{ _id: 0, host: 'configsvr1:27019' }, { _id: 1, host: 'configsvr2:27019' }, { _id: 2, host: 'configsvr3:27019' }]})"
```

## 3. Инициализируйте реплика-сеты шардов

shard1ReplSet:
```bash
docker compose exec -T shard1-node1 mongosh --port 27018 --quiet "--eval" "rs.initiate({_id: 'shard1ReplSet',members: [{ _id: 0, host: 'shard1-node1:27018' },{ _id: 1, host: 'shard1-node2:27018' },{ _id: 2, host: 'shard1-node3:27018' }]})"
````
shard2ReplSet:
```bash
docker compose exec -T shard2-node1 mongosh --port 27018 --quiet "--eval" "rs.initiate({_id: 'shard2ReplSet',members: [{ _id: 0, host: 'shard2-node1:27018' },{ _id: 1, host: 'shard2-node2:27018' },{ _id: 2, host: 'shard2-node3:27018' }]})"
```

## 4. Добавьте шарды в mongos
```bash
docker compose exec -T mongos mongosh --port 27017 --quiet "--eval" "sh.addShard('shard1ReplSet/shard1-node1:27018,shard1-node2:27018,shard1-node3:27018'); sh.addShard('shard2ReplSet/shard2-node1:27018,shard2-node2:27018,shard2-node3:27018')"
```

## 5. Включите шардирование
```bash
docker compose exec -T mongos mongosh --port 27017 --quiet "--eval" "sh.enableSharding('somedb'); db.adminCommand({shardCollection: 'somedb.helloDoc', key: {_id: 'hashed'}})"
```

## 6. Проверка работы кластера

* http://localhost:8080/
* http://localhost:8080/helloDoc/count

Ожидаемый ответ: "items_count": 1000

```bash
docker compose exec -T mongos mongosh --port 27017 --quiet "--eval" "sh.status()"
```
* В разделе shards есть shard1ReplSet и shard2ReplSet.
* Коллекция somedb.helloDoc шардирована
* numOwnedDocuments в сумме дают 1000 у двух шардов

## 7. Проверка репликации
### Количество реплик в shard1ReplSet:
```bash
docker compose exec -T shard1-node1 mongosh --port 27018 --quiet "--eval" "sh.status()"
```

### Количество реплик в shard2ReplSet:
```bash
docker compose exec -T shard2-node1 mongosh --port 27018 --quiet "--eval" "sh.status()"
```

