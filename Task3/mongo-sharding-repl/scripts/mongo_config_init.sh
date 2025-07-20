#!/usr/bin/env bash

mongosh --host config --port 27017 --eval '
rs.initiate({
  _id : "config",
  configsvr: true,
  members: [
    { _id : 0, host : "config:27017" }
  ]
})'
