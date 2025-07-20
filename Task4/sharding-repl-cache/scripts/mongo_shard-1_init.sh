#!/usr/bin/env bash

mongosh --host shard-1-1 --port 27017 --eval '
rs.initiate({
    _id : "shard-1",
    members: [
      { _id : 0, host : "shard-1-1:27017" },
      { _id : 1, host : "shard-1-2:27017" },
      { _id : 2, host : "shard-1-3:27017" }
    ]
})'
