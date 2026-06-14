# MongoDB sharding

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
docker compose exec -T mongos mongosh --port 27017 --quiet --eval \
  'db.getSiblingDB("somedb").helloDoc.getShardDistribution()'
```

В JSON API коллекция `helloDoc` содержит не менее 1200 документов, а
`shard_document_counts` показывает распределение между `shard1Rs` и `shard2Rs`.
