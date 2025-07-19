#!/usr/bin/env bash

mongosh --host shard2 --port 27019 --eval '
rs.initiate({
    _id : "shard2",
    members: [
      { _id : 1, host : "shard2:27019" }
    ]
})'
