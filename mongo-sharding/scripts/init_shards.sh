#!/bin/bash
echo "===> Инициализация Shard1 и Shard2"

docker exec -i shard1 mongosh --quiet --port 27018 --eval '
rs.initiate({
  _id: "shard1",
  members: [
    { _id: 0, host: "shard1:27018" }
  ]
});
'

docker exec -i shard2 mongosh --quiet --port 27019 --eval '
rs.initiate({
  _id: "shard2",
  members: [
    { _id: 0, host: "shard2:27019" }
  ]
});
'

echo "===> Shards инициализированы"
