# MongoDB Sharding Setup

This project sets up a MongoDB sharded cluster with 2 shards, 1 config server, and Redis for caching.

## Architecture

- 1 Config Server (configsvr)
- 2 Shards (1 replica each)
  - Shard 1: shard1
  - Shard 2: shard2
- 1 Mongos Router
- 1 Redis Cache
- 1 API Service

## Prerequisites

- Docker and Docker Compose installed
- At least 2GB of RAM available
- Ports 27016-27019 and 6379 available

## Setup Steps

1. Start the containers:
```bash
docker compose up -d
```

2. Initialize the Config Server Replica Set:
```bash
docker exec -it configsvr mongosh --eval '
rs.initiate({
  _id: "configrs",
  configsvr: true,
  members: [
    {_id: 0, host: "configsvr:27017"}
  ]
})'
```

3. Initialize Shard 1 Replica Set:
```bash
docker exec -it shard1 mongosh --eval '
rs.initiate({
  _id: "shard1rs",
  members: [
    {_id: 0, host: "shard1:27017"}
  ]
})'
```

4. Initialize Shard 2 Replica Set:
```bash
docker exec -it shard2 mongosh --eval '
rs.initiate({
  _id: "shard2rs",
  members: [
    {_id: 0, host: "shard2:27017"}
  ]
})'
```

5. Add Shards to the Cluster:
```bash
docker exec -it mongos mongosh --eval '
sh.addShard("shard1rs/shard1:27017")
sh.addShard("shard2rs/shard2:27017")'
```

6. Enable Sharding for a Database:
```bash
docker exec -it mongos mongosh --eval '
sh.enableSharding("your_database_name")'
```

7. Shard a Collection:
```bash
docker exec -it mongos mongosh --eval '
sh.shardCollection("your_database_name.your_collection", { shardKey: 1 })'
```

8. Seed db 
```
sh mongo-sharding/scripts/mongo-init.sh
```

## Verification

1. Check Config Server Status:
```bash
docker exec -it configsvr mongosh --eval 'rs.status()'
```

2. Check Shard Status:
```bash
docker exec -it mongos mongosh --eval 'sh.status()'
```

3. Check Redis Connection:
```bash
docker exec -it redis redis-cli ping
```

## How to run


```shell
docker compose up -d
```