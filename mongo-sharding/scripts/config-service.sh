#!/bin/bash

###
#Подключаемся и инициализируем сервис конфигурации
###

docker compose exec -T configSrv mongosh --port 27017 <<EOF
rs.initiate(
  {
    _id : "config_server",
       configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" }
    ]
  }
);
EOF

echo "Скрипт выполнен. Результаты выше."
read -p "Нажмите Enter, чтобы выйти..." DUMMY