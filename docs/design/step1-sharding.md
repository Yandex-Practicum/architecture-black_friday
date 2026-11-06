# Task 1, step 1: sharding

The application connects to a `mongos` query router instead of a data node directly. The router uses `configSrv` metadata to distribute requests across two independent shards:

- `shard1` stores one part of the `somedb.helloDoc` collection.
- `shard2` stores the other part of the collection.
- `configSrv` stores the cluster metadata required by `mongos`.

This increases read and write throughput because MongoDB can process requests on both shards. The diagram does not include replica members yet; that is added in step 2.

Diagram: [step1-sharding.drawio](step1-sharding.drawio)

Reference material: [sharding sample image](../internal/task/samples/sharding.png), [MongoDB sharding Compose sample](../internal/task/Samples/replicas-sharding/mongodb/sharding-docker-compose.yaml), and [initialization flow](../internal/task/Samples/replicas-sharding/mongodb/sharding-flow.txt).
