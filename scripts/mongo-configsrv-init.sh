#!/bin/bash

docker compose up configSrv -d --build

until [ "$(docker inspect -f '{{.State.Health.Status}}' configSrv)" == "healthy" ]; do sleep 1; done

docker compose exec -T configSrv mongosh --port 27019 --quiet <<EOF
rs.initiate({_id : "config_server", configsvr: true, members: [{ _id : 0, host : "configSrv:27019" }]});
exit();
EOF

echo "configSrv is initialized"