# Инициализация шардирования, репликации и кеширования

Этот проект реализует:
- Шардирование MongoDB
- Репликацию каждого шарда (3 ноды)
- Кеширование запросов через Redis

---
* возможно потребуется перезапустить mongos
```bash
  docker compose down mongos
```
```bash
  docker compose up -d mongos
```
## 1. Запустите сервисы
```bash
docker compose up -d
```
или только (при перезапуске mongos)
```bash
docker compose up -d pymongo_api
```

## 2. Инициализируйте config servers
```bash
docker compose exec -T configsvr1 mongosh --port 27019 --quiet "--eval" "rs.initiate({_id: 'configReplSet', configsvr: true, members: [{ _id: 0, host: 'configsvr1:27019' }, { _id: 1, host: 'configsvr2:27019' }, { _id: 2, host: 'configsvr3:27019' }]})"
```

## 3. Инициализируйте реплика-сеты шардов

shard1ReplSet:
```bash
docker compose exec -T shard1-node1 mongosh --port 27018 --quiet "--eval" "rs.initiate({_id: 'shard1ReplSet',members: [{ _id: 0, host: 'shard1-node1:27018' },{ _id: 1, host: 'shard1-node2:27018' },{ _id: 2, host: 'shard1-node3:27018' }]})"
```
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

Проверьте логи
```bash
docker compose logs -f pymongo_api
```

## 6. Проверка работы кластера

* http://localhost:8080/

* http://localhost:8080/helloDoc/count

Ожидаемый ответ: {"status":"OK","mongo_db":"somedb","items_count":1000}

Проверка состояния кластера:
```bash
docker compose exec -T mongos mongosh --port 27017 --quiet "--eval" "sh.status()"
```
```bash
docker compose exec -T shard1-node1 mongosh --port 27018 --quiet "--eval" "use somedb db.helloDoc.countDocuments()"
```
* В разделе shards есть shard1ReplSet и shard2ReplSet.
* Коллекция somedb.helloDoc шардирована
* numOwnedDocuments в сумме дают 1000 у двух шардов

## 7. Проверка репликации
### Количество реплик в shard1ReplSet:
```bash
docker compose exec -T shard1-node1 mongosh --port 27018 --quiet "--eval" "rs.status().members.length"
```

### Количество реплик в shard2ReplSet:
```bash
docker compose exec -T shard2-node1 mongosh --port 27018 --quiet "--eval" "rs.status().members.length"
```

## 8. Проверка кеширования
Выполните запрос дважды и посмотрите в DevTools браузера:

http://localhost:8080/helloDoc/users

либо
```bash
curl -o NUL -s -w "Первый запрос: %{time_total} сек\n" http://localhost:8080/helloDoc/users
```
```bash
curl -o NUL -s -w "Второй запрос: %{time_total} сек\n" http://localhost:8080/helloDoc/users
```

Ожидаемый результат: 
* Первый запрос: ~1 секунда (из-за time.sleep(1))
* Второй запрос: <100 мс (из кеша Redis)