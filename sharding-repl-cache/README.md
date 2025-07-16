# pymongo-api

## Как запустить

Запускаем mongodb и приложение

```shell
docker compose up -d
```

Настраиваем шардирование, заполняем mongodb данными и проверяем результат

```shell
./scripts/sharding-cache-init.sh
```

## Как проверить

### Проверяем доступность приложения

Откройте в браузере http://localhost:8080


### Проверяем распределение по шардам

Проверки распределения по шардам были выполнены при инициализации. Их можно произвести вручную запустив команды
```shell
echo "Записей в Shard1:"
docker exec -i shard1-1 mongosh --port 27018 --eval '
  db = db.getSiblingDB("somedb");
  db.helloDoc.countDocuments();
'
echo "Записей в Shard2:"
docker exec -i shard2-1 mongosh --port 27019 --eval '
  db = db.getSiblingDB("somedb");
  db.helloDoc.countDocuments();
'
```

### Проверяем состояние реплик
Проверки состояния реплик были выполнены при инициализации. Их можно произвести вручную запустив команды
```shell
echo "Статус Config Server:"
docker exec -i configSrv mongosh --port 27017 --eval 'rs.status().members.map(m => `${m.name}: ${m.stateStr}`).join("\n")'
echo "Статус Shard1:"
docker exec -i shard1-1 mongosh --port 27018 --eval 'rs.status().members.map(m => `${m.name}: ${m.stateStr}`).join("\n")'
echo "Статус Shard2:"
docker exec -i shard2-1 mongosh --port 27019 --eval 'rs.status().members.map(m => `${m.name}: ${m.stateStr}`).join("\n")'
echo "Cтатус Routers:"
for router in mongos_router mongos_router2 mongos_router3; do
  status=$(docker exec -i $router mongosh --port 27020 --quiet --eval '
    try {
      db.adminCommand({ping:1}).ok ? "ONLINE" : "DEGRADED"
    } catch(e) {
      "OFFLINE"
    }')
  echo "  $router: $status"
done
```
### Проверяем состояние кэша
Проверки состояния кэша были выполнены при инициализации. Их можно произвести вручную запустив команды
```shell
echo "Статус Redis:"
for redis_node in redis_1 redis_2 redis_3 redis_4; do
role=$(docker exec -i $redis_node redis-cli INFO replication | grep -E '^role')
echo "  $redis_node: $role"
done
```

### Проверяем время отклика сервера с использованием кэшируемого запроса

```shell
./scripts/test-cache-timing.sh
```
