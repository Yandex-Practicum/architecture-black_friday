# Task 1, step 3: Redis caching

This version is based on the replicated sharded design from step 2. A `redis` instance is added beside the application:

- `pymongo-api` checks Redis for cached responses to repeated reads.
- A cache hit is returned without contacting MongoDB.
- On a cache miss, the application sends the request to `mongos`, which routes it to the appropriate shard.
- The cache is intended for the `/{collection_name}/users` endpoint, matching the application implementation.

The application connection should use `REDIS_URL=redis://redis:6379`. Redis improves latency for repeated reads, while MongoDB remains the source of truth.

Diagram: [step3-cache.drawio](step3-cache.drawio)

Reference material: [Redis Compose sample](../internal/task/Samples/replicas-sharding/redis/docker-compose.yaml), [Redis cluster flow](../internal/task/Samples/replicas-sharding/redis/flow.txt), and [Redis API example](../internal/task/Samples/replicas-sharding/nodejs-api/index.js).
