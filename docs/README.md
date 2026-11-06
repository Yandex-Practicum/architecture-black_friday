# Architecture task results

This directory contains the planning artifacts for Task 1 of the Mobile World architecture project. Each diagram is a separate copy of the previous stage so the design evolution can be reviewed step by step.

The source map is documented in [docs/internal/inventory.md](internal/inventory.md). It records the assignment materials, reusable MongoDB and Redis samples, and which later-stage samples were intentionally not included in Task 1.

## Task 1

1. [Step 1: sharding](design/step1-sharding.md) - application traffic goes through `mongos` to two MongoDB shards.
2. [Step 2: replication](design/step2-replication.md) - each shard has three replica-set members.
3. [Step 3: Redis caching](design/step3-cache.md) - Redis caches repeated application reads before MongoDB is queried.
4. [Task 5: Service Discovery and API Gateway](design/step4-service-discovery.md) - APISIX balances multiple API instances and discovers them through Consul.
5. [Task 6: CDN](design/step5-cdn.md) - regional CDN edges serve static content close to users.

The Draw.io files are linked from each step document:

- [Step 1 diagram](design/step1-sharding.drawio)
- [Step 2 diagram](design/step2-replication.drawio)
- [Step 3 diagram](design/step3-cache.drawio)
- [Task 5 diagram](design/step4-service-discovery.drawio)
- [Task 6 diagram](design/step5-cdn.drawio)

The third diagram is the final Task 1 design. The fourth diagram extends it for Task 5 with three application instances, APISIX, etcd, and a three-node Consul service-discovery cluster. The fifth diagram adds regional CDN edges and the static-content origin for Task 6.
