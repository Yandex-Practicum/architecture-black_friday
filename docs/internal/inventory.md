# Architecture source inventory

This inventory maps the source materials used for the Task 1 planning artifacts and records how each source was applied.

## Project sources

| Source | Role | Applied to |
| --- | --- | --- |
| [Task description](task/description.md) | Defines the three Task 1 stages, required service labels, replica count, and diagram expectations. | All Task 1 diagrams and step notes. |
| [Original Draw.io template](task/task1.drawio) | Baseline diagram containing `pymongo-api` and one MongoDB node. | Starting point for the diagram series. |
| [Original architecture image](task/Image.png) | Visual reference included with the assignment. | General layout and terminology. |
| [Sharding reference image](task/samples/sharding.png) | Shows an application driver, multiple routers, a configuration server, and shard groups with primary and secondary nodes. | Validated the use of `mongos`, `configSrv`, and grouped shard members. |

## Reusable implementation samples

| Source | Relevant details | Applied to |
| --- | --- | --- |
| [MongoDB sharding Compose](task/Samples/replicas-sharding/mongodb/sharding-docker-compose.yaml) | Uses `configSrv`, `shard1`, `shard2`, and `mongos_router`; MongoDB processes run with `--configsvr` or `--shardsvr`. | Service naming and the router/config-server relationship. |
| [MongoDB sharding flow](task/Samples/replicas-sharding/mongodb/sharding-flow.txt) | Initializes the config server and shards, adds both shards to `mongos`, enables sharding, and hashes `somedb.helloDoc` by `name`. | Step 1 explanation and the intended data-routing behavior. |
| [MongoDB replica Compose](task/Samples/replicas-sharding/mongodb/docker-compose.yaml) | Runs three MongoDB members in one replica set with `--replSet`. | Step 2’s three-member replica-set model. |
| [Redis Compose](task/Samples/replicas-sharding/redis/docker-compose.yaml) | Shows Redis services attached to the application network. | Step 3’s application-to-Redis cache path; the task diagram intentionally uses one Redis instance. |
| [Redis cluster flow](task/Samples/replicas-sharding/redis/flow.txt) | Demonstrates Redis masters and replicas with `--cluster-replicas 1`. | Reference only; Redis clustering is outside Task 1’s requested single-cache-instance scope. |
| [Redis API example](task/Samples/replicas-sharding/nodejs-api/index.js) | Reads by request URL and invalidates cache entries after writes. | Confirms the cache-before-database interaction shown in step 3. |
| [Node.js API package](task/Samples/replicas-sharding/nodejs-api/package.json) | Lists Express, Mongoose, and Redis dependencies. | Dependency reference only; the project uses the existing Python API. |
| [Load-balancer Compose](task/Samples/replicas-sharding/load-balancer/docker-compose.yml) | Demonstrates APISIX, etcd, multiple web instances, and Consul. | Reference for later Task 5 work, not included in Task 1 diagrams. |
| [Load-balancer flow](task/Samples/replicas-sharding/load-balancer/flow.txt) | Shows Consul service registration and APISIX discovery. | Reference for later Service Discovery and API Gateway work. |
| [PostgreSQL/Citus flow](task/Samples/replicas-sharding/PostgreSQL/sharding-flow.txt) | Demonstrates PostgreSQL distributed-table setup. | Not used; the assignment requires MongoDB sharding. |

## Produced artifacts

| Artifact | Result |
| --- | --- |
| [Task 1 index](../README.md) | Links the three stages and their diagrams. |
| [Step 1 notes](../design/step1-sharding.md) and [diagram](../design/step1-sharding.drawio) | Two MongoDB shards behind `mongos`. |
| [Step 2 notes](../design/step2-replication.md) and [diagram](../design/step2-replication.drawio) | Three replica members for each shard. |
| [Step 3 notes](../design/step3-cache.md) and [diagram](../design/step3-cache.drawio) | Redis cache in front of the replicated sharded MongoDB cluster. |

The diagrams remain intentionally limited to Task 1. API Gateway, Consul, horizontal application scaling, and CDN belong to later assignment stages and are tracked as reference material rather than being added here.
