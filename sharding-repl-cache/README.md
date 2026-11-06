# MongoDB sharding, replication, and Redis cache

This project is the Task 4 implementation. It combines the Task 2 sharded MongoDB stand and the Task 3 three-member replica sets with a Redis cache for repeated application reads.

## Topology

- `configSrv` stores sharding metadata in the single-member `config_server` replica set used by this development stand.
- `shard1-1`, `shard1-2`, and `shard1-3` form the `shard1` replica set.
- `shard2-1`, `shard2-2`, and `shard2-3` form the `shard2` replica set.
- `mongos_router` routes application requests to the sharded MongoDB cluster.
- `redis` stores cached responses.
- `pymongo_api` connects to MongoDB through `mongos_router` and to Redis through `REDIS_URL=redis://redis:6379`.

The API cache is enabled for `/{collection_name}/users`. MongoDB remains the source of truth; repeated reads are served from Redis until the one-minute cache entry expires.

## Start and initialize

From this directory, start the services:

```shell
docker compose up -d
```

Run the initialization script. It is safe to run again after the stand is already initialized:

```shell
./scripts/mongo-init.sh
```

The script initializes the config server, initializes both three-member shard replica sets, registers both replica sets in `mongos`, enables sharding for `somedb`, shards `somedb.helloDoc` by hashed `name`, and inserts 1000 documents.

Check service status:

```shell
docker compose ps
```

## Verify MongoDB and Redis

Open the API response at <http://localhost:8080> or its Swagger UI at <http://localhost:8080/docs>.

The root response must report:

- `"mongo_topology_type": "Sharded"`
- `"shard_replica_counts": {"shard1": 3, "shard2": 3}`
- `"cache_enabled": true`
- 1000 documents in `helloDoc`

The count endpoint reports the total:

```shell
curl http://localhost:8080/helloDoc/count
```

Confirm distribution and replica membership directly:

```shell
docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments()'
docker compose exec -T shard2-1 mongosh --port 27021 --quiet --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments()'
docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval 'rs.status().members.length'
docker compose exec -T shard2-1 mongosh --port 27021 --quiet --eval 'rs.status().members.length'
docker compose exec -T redis redis-cli ping
```

The two shard counts must both be non-zero and sum to 1000. Each replica-member command must return `3`, and Redis must return `PONG`.

## Verify cache speed

Use the same URL twice. The first request populates Redis and includes the application’s one-second database delay; subsequent requests should be below 100ms:

```shell
curl --silent --output /dev/null --write-out 'first request: %{time_total}s\n' http://localhost:8080/helloDoc/users
curl --silent --output /dev/null --write-out 'second request: %{time_total}s\n' http://localhost:8080/helloDoc/users
curl --silent --output /dev/null --write-out 'third request: %{time_total}s\n' http://localhost:8080/helloDoc/users
```

The second and third timings must be less than `0.100s`. If the cache was already populated, clear it and repeat the measurement:

```shell
docker compose exec -T redis redis-cli FLUSHDB
```

## Reproduce from a clean stand

Run these commands from `sharding-repl-cache` in Git Bash with Docker Desktop integration enabled:

```shell
docker compose down -v
docker compose up -d --build
./scripts/mongo-init.sh
curl --silent http://localhost:8080/ | jq
curl --silent http://localhost:8080/helloDoc/count | jq
```

To stop the stand:

```shell
docker compose down
```

To remove its persisted data as well:

```shell
docker compose down -v
```
