# Task 5: Service Discovery and API Gateway

This fourth design variant builds on the Task 4 cache-enabled topology and adds horizontal application scaling:

- `users` send HTTP requests to the `apisix` API Gateway.
- `apisix` balances traffic across `pymongo-api-1`, `pymongo-api-2`, and `pymongo-api-3`.
- The three application instances register with the `consul-1`, `consul-2`, and `consul-3` Consul service-discovery cluster.
- Consul returns the current application instances to APISIX, so adding or removing an application instance does not require a fixed gateway configuration.
- `etcd` stores APISIX configuration, following the provided APISIX sample.
- Every application instance keeps the existing Redis cache and `mongos` connection to the sharded, replicated MongoDB cluster.

The diagram shows load-balancing, service registration, service discovery, cache, database, and replica-set interactions with directional arrows.

Diagram: [step4-service-discovery.drawio](step4-service-discovery.drawio)

Reference material: [APISIX, etcd, and Consul Compose sample](../internal/task/Samples/replicas-sharding/load-balancer/docker-compose.yml) and [Consul registration flow](../internal/task/Samples/replicas-sharding/load-balancer/flow.txt).
