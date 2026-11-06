# MongoDB sharding and replication stand

This project is the Task 3 implementation. It runs the Python API through a MongoDB `mongos` router and distributes `somedb.helloDoc` across two MongoDB shards. Each shard has three replica-set members.

## Topology

- `configSrv` stores sharding metadata in the single-member `config_server` replica set used by this development stand.
- `shard1-1`, `shard1-2`, and `shard1-3` form the three-member `shard1` replica set.
- `shard2-1`, `shard2-2`, and `shard2-3` form the three-member `shard2` replica set.
- `mongos_router` is the application-facing query router.
- `pymongo_api` connects to `mongodb://mongos_router:27024`.

Each shard has one primary and two secondary members. A primary failure can therefore be handled by replica-set election without losing the shard’s data.

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

## Verify

Open the API response at <http://localhost:8080> or its Swagger UI at <http://localhost:8080/docs>.

The root response reports the `Sharded` MongoDB topology, both shards, and their replica counts. The count endpoint reports the total:

```shell
curl http://localhost:8080/helloDoc/count
```

## Reproduce the verification

Run these commands from `mongo-sharding-repl` in Git Bash with Docker Desktop integration enabled:

```shell
docker compose down -v
docker compose up -d --build
./scripts/mongo-init.sh
docker compose ps
curl --silent http://localhost:8080/ | jq
curl --silent http://localhost:8080/helloDoc/count | jq
```

The root response must contain `"mongo_topology_type": "Sharded"` and both `shard1` and `shard2` entries with three members in their connection strings. The `helloDoc` collection and count endpoint must report 1000 documents.

Confirm distribution and replica membership directly:

```shell
docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval 'db.getMongo().setReadPref("secondaryPreferred"); db.getSiblingDB("somedb").helloDoc.countDocuments()'
docker compose exec -T shard2-1 mongosh --port 27021 --quiet --eval 'db.getMongo().setReadPref("secondaryPreferred"); db.getSiblingDB("somedb").helloDoc.countDocuments()'
docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval 'rs.status().members.length'
docker compose exec -T shard2-1 mongosh --port 27021 --quiet --eval 'rs.status().members.length'
```

The two shard counts must both be non-zero and sum to 1000. Each replica-member command must return `3`.

To stop the stand:

```shell
docker compose down
```

To remove its persisted data as well:

```shell
docker compose down -v
```
