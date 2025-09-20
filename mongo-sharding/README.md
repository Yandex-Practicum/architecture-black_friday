# Mongo Sharding Example

Этот проект демонстрирует развертывание MongoDB с шардированием, добавление тестовой коллекции `helloDoc` с 50 000 документов и распределение данных по двум шардам.


## Шаг 1. Запуск Docker Compose

В корне проекта:

```bash
docker compose up -d
```
Контейнеры, которые будут созданы:
- 2 шарда (shard1, shard2)
- Конфигурационный сервер (configSrv)
- тер (mongos_router)
## Шаг 2. Инициализация сервисов по назначению
### Конфигурация
Открываем контейнер конфигурации 
```bash
docker exec -it configSrv mongosh --port 27017
```
Инициализируем конфигурацию
```bash
> rs.initiate(
  {
    _id : "config_server",
       configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" }
    ]
  }
);

```
Выход через `exit`
### Шарды
Открываем контейнер шарда №1
```bash
docker exec -it shard1 mongosh --port 27018
```
Инициализируем шард №1
```bash
> rs.initiate(
    {
      _id : "shard1",
      members: [
        { _id : 0, host : "shard1:27018" },
       // { _id : 1, host : "shard2:27019" }
      ]
    }
);
```
Выход через `exit`

Открываем контейнер шарда №2
```bash
docker exec -it shard2 mongosh --port 27019
```
Инициализируем шард №2
```bash
> rs.initiate(
    {
      _id : "shard2",
      members: [
       // { _id : 0, host : "shard1:27018" },
        { _id : 1, host : "shard2:27019" }
      ]
    }
  );
```
Выход через `exit`
### Настройка роутера и создание данных

Открываем контейнер шарда №2
```bash
docker exec -it mongos_router mongosh --port 27020
```
Регистрируем шарды по очереди 
```bash
> sh.addShard( "shard1/shard1:27018");
> sh.addShard( "shard2/shard2:27019");
```
Инициализируем `somedb` и включаем шардирование
```bash
> sh.enableSharding("somedb");
```
Создаем коллекцию
```bash
> db.createCollection("helloDoc")
```
Задаем правило шардирования коллекции
```bash
> sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )
```
Переключаемся на БД и вставляем данные 
```bash
>use somedb
>const names = ["Alice","Bob","Charlie","Diana","Eve","Frank","Grace","Hank","Ivy","Jack"];
const docs = [];

for (let i = 0; i < 50000; i++) {
  const randomName = names[Math.floor(Math.random() * names.length)] + "_" + i;
  docs.push({
    _id: UUID(),
    name: randomName,
    age: Math.floor(Math.random() * 100)
  });

  if (docs.length === 1000) {
    db.helloDoc.insertMany(docs);
    docs.length = 0;
  }
}

// Вставляем остаток
if (docs.length > 0) db.helloDoc.insertMany(docs);

// Проверяем количество документов во всех шардах
>db.helloDoc.countDocuments()
```