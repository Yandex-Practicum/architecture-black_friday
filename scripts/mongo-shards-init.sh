#!/bin/bash

docker compose up shard1-1 shard1-2 shard1-3 shard2-1 shard2-2 shard2-3 -d --build

until [ "$(docker inspect -f '{{.State.Health.Status}}' shard1-1)" == "healthy" ]; do sleep 3; done

###
# Shard1
###
docker compose exec -T shard1-1 mongosh --port 27020 --quiet <<EOF
rs.initiate({_id: "shard1", members: [{_id: 0, host: "shard1-1:27020"},{_id: 1, host: "shard1-2:27021"},{_id: 2, host: "shard1-3:27022"}]})
EOF

echo "shard1 is initialized"

###
# Shard2
###
docker compose exec -T shard2-1 mongosh --port 27030 --quiet <<EOF
rs.initiate({_id : "shard2", members: [{_id: 0, host: "shard2-1:27030"},{_id: 1, host: "shard2-2:27031"},{_id: 2, host: "shard2-3:27032"}]});
exit();
EOF

echo "shard2 is initialized"