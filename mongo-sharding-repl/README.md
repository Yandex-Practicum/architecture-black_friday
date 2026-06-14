# MongoDB sharding with replication

## Запуск

```bash
docker compose up -d
chmod +x scripts/init.sh
./scripts/init.sh
```

## Проверка

```bash
docker compose ps
curl -s http://localhost:8080/ | jq
docker compose exec -T shard1-1 mongosh --port 27017 --quiet --eval \
  'rs.status().members.map(({name,stateStr}) => ({name,stateStr}))'
docker compose exec -T shard2-1 mongosh --port 27017 --quiet --eval \
  'rs.status().members.map(({name,stateStr}) => ({name,stateStr}))'
```

В JSON API коллекция `helloDoc` содержит не менее 1200 документов,
`shard_document_counts` показывает распределение, а `shard_replica_counts`
содержит значение `3` для каждого шарда.
