#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Инициализация replica set для сервера конфигурации (config_server)..."
docker compose exec -T configSrv mongosh --port 27017 --quiet --eval "
  try {
    rs.initiate({
      _id: 'config_server',
      configsvr: true,
      members: [{_id: 0, host: 'configSrv:27017'}]
    });
  } catch(e) {
    if (!e.toString().includes('already initialized')) throw e;
  }
" >/dev/null 2>&1
sleep 2

echo "[INFO] Инициализация replica set для шарда 1 (shard1) с 3 нодами..."
docker compose exec -T shard1 mongosh --port 27018 --quiet --eval "
  try {
    rs.initiate({
      _id: 'shard1',
      members: [
        {_id: 0, host: 'shard1:27018'},
        {_id: 1, host: 'shard1-rs2:27021'},
        {_id: 2, host: 'shard1-rs3:27024'}
      ]
    });
  } catch(e) {
    if (!e.toString().includes('already initialized')) throw e;
  }
" >/dev/null 2>&1
sleep 2

echo "[INFO] Инициализация replica set для шарда 2 (shard2) с 3 нодами..."
docker compose exec -T shard2 mongosh --port 27019 --quiet --eval "
  try {
    rs.initiate({
      _id: 'shard2',
      members: [
        {_id: 0, host: 'shard2:27019'},
        {_id: 1, host: 'shard2-rs2:27022'},
        {_id: 2, host: 'shard2-rs3:27025'}
      ]
    });
  } catch(e) {
    if (!e.toString().includes('already initialized')) throw e;
  }
" >/dev/null 2>&1
sleep 2

echo "[INFO] Настройка маршрутизатора (mongos): добавление шардов, включение шардирования и настройка коллекции..."
docker compose exec -T mongos_router mongosh --port 27020 --quiet --eval "
  try {
    sh.addShard('shard1/shard1:27018,shard1-rs2:27021,shard1-rs3:27024');
    sh.addShard('shard2/shard2:27019,shard2-rs2:27022,shard2-rs3:27025');
    sh.enableSharding('somedb');
    sh.shardCollection('somedb.helloDoc', { name: 'hashed' });
  } catch(e) {
    print('Ошибка при настройке шардирования: ' + e);
    throw e;
  }
" >/dev/null 2>&1
sleep 2

echo "[INFO] Заполнение коллекции helloDoc в базе somedb тестовыми данными (1000 документов)..."
docker compose exec -T mongos_router mongosh --port 27020 --quiet --eval "
  const db = db.getSiblingDB('somedb');
  if (!db.helloDoc) {
    db.createCollection('helloDoc');
  }
  db.helloDoc.bulkWrite(
    Array.from({ length: 1000 }, (_, i) => ({
      insertOne: { document: { age: i, name: 'ly' + i } }
    }))
  );
" >/dev/null 2>&1
sleep 2

echo "[INFO] Подсчёт количества документов в коллекции helloDoc на шарде 1..."
count1=$(docker compose exec -T shard1 mongosh --port 27018 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()" 2>/dev/null)
echo "[RESULT] Количество документов на шарде 1: $count1"

echo "[INFO] Подсчёт количества документов в коллекции helloDoc на шарде 2..."
count2=$(docker compose exec -T shard2 mongosh --port 27019 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()" 2>/dev/null)
echo "[RESULT] Количество документов на шарде 2: $count2"

total=$((count1 + count2))
echo "[SUMMARY] Всего документов по шардам: $total (из 1000 вставленных)"
