# Architecture task results

This directory contains the planning artifacts for Task 1 of the Mobile World architecture project. Each diagram is a separate copy of the previous stage so the design evolution can be reviewed step by step.

The source map is documented in [docs/internal/inventory.md](internal/inventory.md). It records the assignment materials, reusable MongoDB and Redis samples, and which later-stage samples were intentionally not included in Task 1.

## Task 1

1. [Step 1: sharding](design/step1-sharding.md) - application traffic goes through `mongos` to two MongoDB shards.
2. [Step 2: replication](design/step2-replication.md) - each shard has three replica-set members.
3. [Step 3: Redis caching](design/step3-cache.md) - Redis caches repeated application reads before MongoDB is queried.

The Draw.io files are linked from each step document:

- [Step 1 diagram](design/step1-sharding.drawio)
- [Step 2 diagram](design/step2-replication.drawio)
- [Step 3 diagram](design/step3-cache.drawio)

The final Task 1 design is the third diagram. It includes the application, Redis, `mongos`, `configSrv`, two shards, and three replica members for each shard, with network interactions and replica-set grouping shown.
