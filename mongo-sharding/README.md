# MongoDB sharding stand

This project is the Task 2 implementation. It runs the Python API through a MongoDB `mongos` router and distributes `somedb.helloDoc` across two MongoDB shards.

## Topology

- `configSrv` stores sharding metadata.
- `shard1` and `shard2` are MongoDB shard replica sets with one member each in this Task 2 stand.
- `mongos_router` is the application-facing query router.
- `pymongo_api` connects to `mongodb://mongos_router:27020`.

The next assignment stage expands the shard replica sets to three members each.

## Start and initialize

From this directory, start the services:

```shell
docker compose up -d
```

Run the initialization script. It is safe to run again after the stand is already initialized:

```shell
./scripts/mongo-init.sh
```

The script initializes the config-server replica set, initializes both shard replica sets, registers both shards in `mongos`, enables sharding for `somedb`, shards `somedb.helloDoc` by hashed `name`, and inserts 1000 documents.

Check service status:

```shell
docker compose ps
```

## Verify

Open the API response at http://localhost:8080 or its Swagger UI at http://localhost:8080/docs.

The root response should report a `Sharded` MongoDB topology, the `somedb` database, and both configured shards. The count endpoint reports the total:

```shell
curl http://localhost:8080/helloDoc/count
```

The initialization script also prints the total count and the count observed directly through each shard. The total must be at least 1000, and both shard counts should be non-zero.

To stop the stand:

```shell
docker compose down
```

To remove its persisted data as well:

```shell
docker compose down -v
```
