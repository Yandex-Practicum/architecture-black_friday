#!/usr/bin/env bash

mongosh --host shard-2-1 --port 27017 --eval '
rs.initiate({
    _id : "shard-2",
    members: [
      { _id : 0, host : "shard-2-1:27017" },
      { _id : 1, host : "shard-2-2:27017" },
      { _id : 2, host : "shard-2-3:27017" }
    ]
})'
