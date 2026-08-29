# Шардирование и репликация MongoDB

![Схема этого этапа](<../task1-2 - Репликация.drawio.svg>)

На этом стенде каждый шард состоит из трёх узлов. В `shard1-rs` входят `shard1-1`, `shard1-2` и `shard1-3`, в `shard2-rs` — три узла с префиксом `shard2`. После выборов в каждом replica set работает один primary и две secondary.

Приложение подключается к `mongos` на порте `27017`. Config server вынесен в отдельный односоставной `config-rs` на порте `27019`.

## Запуск и инициализация

1. Поднимите сервисы из директории `mongo-sharding-repl`:

   ```shell
   docker compose up -d
   ```

2. Настройте MongoDB:

   ```shell
   ./scripts/mongo-init.sh
   ```

   Во время инициализации скрипт:

   - создаёт `config-rs`;
   - собирает `shard1-rs` и `shard2-rs` из трёх узлов каждый;
   - ждёт, пока в обоих наборах выберется primary и подключатся secondary;
   - регистрирует replica set как шарды;
   - включает шардирование `somedb.helloDoc` по хешированному `_id`;
   - создаёт 1000 тестовых документов.

   На чистом стенде выборы primary могут занять около минуты.

3. Проверьте, что все контейнеры работают:

   ```shell
   docker compose ps
   ```

`mongo-init.sh` рассчитан и на повторный запуск: настроенные replica set и существующие документы не дублируются.

## Проверка результата

```shell
curl --silent http://localhost:8080/ | jq
curl --silent http://localhost:8080/helloDoc/count | jq
```

API должен показать топологию `Sharded`, два шарда и не меньше 1000 документов.

Состояние узлов обоих replica set:

```shell
docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval 'rs.status().members.forEach(member => print(member.name + ": " + member.stateStr))'
docker compose exec -T shard2-1 mongosh --port 27018 --quiet --eval 'rs.status().members.forEach(member => print(member.name + ": " + member.stateStr))'
```

Для каждого шарда ожидаются один `PRIMARY` и два `SECONDARY`.

Распределение коллекции между шардами:

```shell
docker compose exec -T mongos mongosh --port 27017 --quiet --eval 'db.getSiblingDB("somedb").helloDoc.getShardDistribution()'
```

## Остановка

```shell
docker compose down
```

Удалить также volumes этого стенда:

```shell
docker compose down -v
```
