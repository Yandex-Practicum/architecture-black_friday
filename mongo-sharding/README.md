# Инициализация шардирования

Этот проект реализует шардирование MongoDB для повышения производительности и масштабируемости.  
Архитектура включает:
- 2 шарда (`shard1ReplSet`, `shard2ReplSet`)
- 3 config server (`configReplSet`) как реплика-сет
- `mongos` — роутер запросов
- `pymongo_api` — FastAPI-приложение, подключающееся к `mongos`

База данных: `somedb`  
Коллекция: `helloDoc`  
Цель: приложение должно отображать общее количество документов (≥1000) и количество на каждом шарде.

---

## 1. Запустите сервисы

```bash
docker compose up -d

## 2. Инициализируйте config servers
```bash
docker compose exec -T configsvr1 mongosh --port 27019 --quiet "--eval" "rs.initiate({_id: 'configReplSet', configsvr: true, members: [{ _id: 0, host: 'configsvr1:27019' }, { _id: 1, host: 'configsvr2:27019' }, { _id: 2, host: 'configsvr3:27019' }]})"
```

## 3. Инициализируйте шарды

Shard 1:
```bash
docker compose exec -T shard1 mongosh --port 27018 --quiet "--eval" "rs.initiate({_id: 'shard1ReplSet', members: [{ _id: 0, host: 'shard1:27018' }]})"
````
Shard 2:
```bash
docker compose exec -T shard2 mongosh --port 27018 --quiet "--eval" "rs.initiate({_id: 'shard2ReplSet', members: [{ _id: 0, host: 'shard2:27018' }]})"
```

## 4. Добавьте шарды в mongos
```bash
docker compose exec -T mongos mongosh --port 27017 --quiet "--eval" "sh.addShard('shard1ReplSet/shard1:27018'); sh.addShard('shard2ReplSet/shard2:27018')"
```

## 5. Включите шардирование
```bash
docker compose exec -T mongos mongosh --port 27017 --quiet "--eval" "sh.enableSharding('somedb'); db.adminCommand({shardCollection: 'somedb.helloDoc', key: {_id: 'hashed'}})"
```

## 6. Запустить и убедиться в правильности
```bash
http://localhost:8080/
http://localhost:8080/helloDoc/count
```
* Ожидаемый ответ: "items_count": 1000

```bash
docker compose exec -T mongos mongosh --port 27017 --quiet "--eval" "sh.status()"
```
* В разделе shards есть shard1ReplSet и shard2ReplSet.
* Коллекция somedb.helloDoc шардирована
* numOwnedDocuments в сумме дают 1000 у двух шардов
