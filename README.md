# MongoDB Sharding Project - Инициализация и Запуск

Этот проект реализует MongoDB с шардированием на базе Docker Compose с двумя шардами, сервером конфигурации и маршрутизатором (mongos).

---

## 1. Запуск контейнеров

Запустите все сервисы:

```bash
docker compose up -d
```

Проверьте, что контейнеры работают:

```bash
docker ps
```

---

## 2. Инициализация сервера конфигурации

Подключитесь к контейнеру сервера конфигурации и инициализируйте replica set:

```bash
docker exec -it configSrv mongosh --port 27017
```

В mongosh выполните:

```js
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv:27017" }
  ]
});
```

Выйдите из shell командой `exit`.

---

## 3. Инициализация шарда 1

Подключитесь к первому шару:

```bash
docker exec -it shard1 mongosh --port 27018
```

Выполните инициализацию replica set для первого шарда:

```js
rs.initiate({
  _id: "shard1",
  members: [
    { _id: 0, host: "shard1:27018" }
  ]
});
```

Выйдите из shell командой `exit`.

---

## 4. Инициализация шарда 2

Подключитесь ко второму шару:

```bash
docker exec -it shard2 mongosh --port 27019
```

Выполните инициализацию replica set для второго шарда:

```js
rs.initiate({
  _id: "shard2",
  members: [
    { _id: 0, host: "shard2:27019" }
  ]
});
```

Выйдите из shell командой `exit`.

---

## 5. Инициализация маршрутизатора (mongos) и добавление шардов

Подключитесь к маршрутизатору:

```bash
docker exec -it mongos_router mongosh --port 27020
```

Добавьте шард 1:

```js
sh.addShard("shard1/shard1:27018");
```

Добавьте шард 2:

```js
sh.addShard("shard2/shard2:27019");
```

---

## 6. Включение шардирования для базы и коллекции

В mongos выполните:

```js
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name": "hashed" });
```

---

## 7. Наполнение базы данных тестовыми данными

Выполните в mongos:

```js
use somedb;
for (var i = 0; i < 1000; i++) {
  db.helloDoc.insert({ age: i, name: "ly" + i });
}
db.helloDoc.countDocuments();
```

Должно вывести число 1000.

---

## 8. Проверка распределения данных на шардах

Проверьте количество документов на первом шарде:

```bash
docker exec -it shard1 mongosh --port 27018
```

```js
use somedb;
db.helloDoc.countDocuments();
exit;
```

Проверьте количество документов на втором шарде:

```bash
docker exec -it shard2 mongosh --port 27019
```

```js
use somedb;
db.helloDoc.countDocuments();
exit;
```

Ожидается, что сумма документов на обоих шардах будет равна 1000.

---

## Полезные команды

- Просмотр статуса replica set на шарде:

```js
rs.status();
```

- Просмотр текущих шардов в mongos:

```js
sh.status();
```