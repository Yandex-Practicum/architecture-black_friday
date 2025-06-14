# MongoDB Sharding Setup with Replica Sets

This project sets up a MongoDB sharded cluster with 2 shards (each with 2 replicas), 1 config server, and Redis for caching.

## Architecture

- 1 Config Server (configsvr)
- 2 Shards (each with 2 replicas)
  - Shard 1: shard1svr1, shard1svr2
  - Shard 2: shard2svr1, shard2svr2
- 1 Mongos Router
- 1 Redis Cache
- 1 API Service

## Prerequisites

- Docker and Docker Compose installed
- At least 4GB of RAM available
- Ports 27016-27021 and 6379 available

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
docker exec -it shard1svr1 mongosh --eval '
rs.initiate({
  _id: "shard1rs",
  members: [
    {_id: 0, host: "shard1svr1:27017"},
    {_id: 1, host: "shard1svr2:27017"}
  ]
})'
```

4. Initialize Shard 2 Replica Set:
```bash
docker exec -it shard2svr1 mongosh --eval '
rs.initiate({
  _id: "shard2rs",
  members: [
    {_id: 0, host: "shard2svr1:27017"},
    {_id: 1, host: "shard2svr2:27017"}
  ]
})'
```

5. Add Shards to the Cluster:
```bash
docker exec -it mongos mongosh --eval '
sh.addShard("shard1rs/shard1svr1:27017,shard1svr2:27017")
sh.addShard("shard2rs/shard2svr1:27017,shard2svr2:27017")'
```

6. Enable Sharding for a Database:
```bash
docker exec -it mongos mongosh --eval '
sh.enableSharding("somedb")'
```

7. Shard a Collection:
```bash
docker exec -it mongos mongosh --eval '
sh.shardCollection("somedb.your_collection", { shardKey: 1 })'
```

8. Seed database:
```bash
sh scripts/mongo-init.sh
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

1. Start all services:
```bash
docker compose up -d
```

2. Wait for all containers to start (about 30 seconds)

3. Run the initialization scripts in order:
```bash
# Initialize config server
docker exec -it configsvr mongosh --eval 'rs.initiate({_id: "configrs", configsvr: true, members: [{_id: 0, host: "configsvr:27017"}]})'

# Initialize shard 1
docker exec -it shard1svr1 mongosh --eval 'rs.initiate({_id: "shard1rs", members: [{_id: 0, host: "shard1svr1:27017"}, {_id: 1, host: "shard1svr2:27017"}]})'

# Initialize shard 2
docker exec -it shard2svr1 mongosh --eval 'rs.initiate({_id: "shard2rs", members: [{_id: 0, host: "shard2svr1:27017"}, {_id: 1, host: "shard2svr2:27017"}]})'

# Add shards to cluster
docker exec -it mongos mongosh --eval 'sh.addShard("shard1rs/shard1svr1:27017,shard1svr2:27017"); sh.addShard("shard2rs/shard2svr1:27017,shard2svr2:27017")'

# Enable sharding
docker exec -it mongos mongosh --eval 'sh.enableSharding("somedb")'

# Shard collection
docker exec -it mongos mongosh --eval 'sh.shardCollection("somedb.your_collection", { shardKey: 1 })'

# Seed database
sh scripts/mongo-init.sh
```

4. Verify the setup:
```bash
# Check sharding status
docker exec -it mongos mongosh --eval 'sh.status()'

# Check Redis
docker exec -it redis redis-cli ping
```

5. Access the API:
- Local: http://localhost:8080
- Remote: http://<your-ip>:8080