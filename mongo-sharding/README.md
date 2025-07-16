# pymongo-api

## Как запустить

Запускаем mongodb и приложение

```shell
docker compose up -d
```

Настраиваем шардирование, заполняем mongodb данными и проверяем результат

```shell
./scripts/sharding-init.sh
```

## Как проверить

### Проверяем доступность приложения

Откройте в браузере http://localhost:8080

### Проверяем распределение по шардам

Проверки распределения по шардам были выполнены при инициализации. Их можно произвести вручную запустив команды
```shell
echo "Записей в Shard1"
docker exec -i shard1 mongosh --port 27018 --eval '
  db = db.getSiblingDB("somedb");
  db.helloDoc.countDocuments();
'
echo "Записей в Shard2"
docker exec -i shard2 mongosh --port 27019 --eval '
  db = db.getSiblingDB("somedb");
  db.helloDoc.countDocuments();
'
```