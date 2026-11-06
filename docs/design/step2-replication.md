# Task 1, step 2: replication

This version is based on the sharded design from step 1. Each shard is now a three-member MongoDB replica set:

- `shard1-1`, `shard1-2`, and `shard1-3` form the `shard1` replica set.
- `shard2-1`, `shard2-2`, and `shard2-3` form the `shard2` replica set.
- Each replica set has one `PRIMARY` and two `SECONDARY` members.
- `mongos` routes application traffic to the shard replica sets, while the primary members replicate data to their secondaries.

Three members per replica set provide automatic primary election and allow the shard to remain available after one member fails. The `configSrv` service remains the source of cluster metadata.

Diagram: [step2-replication.drawio](step2-replication.drawio)

Reference material: [MongoDB replica Compose sample](../internal/task/Samples/replicas-sharding/mongodb/docker-compose.yaml) and [sharding reference image](../internal/task/samples/sharding.png).
