# MongoDB Sharded Cluster with Replication

Архитектура включает:
* 1 Config Server (Replica Set)
* 1 Mongos (Router)
* 2 Shards, каждый из которых является Replica Set из 3-х нод.

## Инструкция по развертыванию

1. **Запуск контейнеров:**
   ```bash
   docker compose up -d

2. Инициализация кластера
Для автоматической настройки репликации и связки шардов запустите PowerShell-скрипт:
./init-all.ps1
Скрипт поочередно инициализирует configReplSet, shard1ReplSet, shard2ReplSet и регистрирует их в mongos.

3. Наполнение данными
Чтобы проверить работу шардирования, создайте базу и залейте тестовые документы (1000 шт.):
docker exec -it mongos mongosh --port 27117 --eval "sh.enableSharding('somedb'); sh.shardCollection('somedb.helloDoc', { _id: 'hashed' }); const col = db.getSiblingDB('somedb').helloDoc; for(var i = 0; i < 1000; i++) col.insertOne({age: i, name: 'user' + i});"

4. Проверка состояния
Приложение доступно по адресу: http://localhost:8080
Там отображается:
Статус подключения к базе.
Общее количество документов (1000).
Распределение данных по реплика-сетам шардов.

5. Используемые порты (Host)
8080: Web API
27117: Mongos (Router)
27119: Config Server
27111-27113: Shard 1 (Nodes 1-3)
27121-27123: Shard 2 (Nodes 1-3)