#!/bin/bash

echo "===> Вставка тестовых данных в somedb.helloDoc"

# Запускаем скрипт insert.js внутри контейнера mongos1
docker exec -i mongos1 mongosh --port 27020 < insert_data.js

echo "===> Вставка завершена"