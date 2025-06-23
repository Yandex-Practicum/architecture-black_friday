# Задание 3. Репликация

1. Поднимаем compose.yaml
2. Настраиваем шарды с репликами
   первый шард
   ```
   docker exec -it shard1 mongosh --port 27011  
   ```
   ```
   rs.initiate({
      _id: "shard1",
      members: [
         { _id: 0, host: "shard1:27011" },
         { _id: 1, host: "shard1-r1:27013" },
         { _id: 2, host: "shard1-r2:27014" },
         { _id: 3, host: "shard1-r3:27015" }
      ]
   });
   ```
   второй шард
   ```
   docker exec -it shard2 mongosh --port 27012
   ```
   ```
   rs.initiate({
      _id: "shard2",
      members: [
         { _id: 0, host: "shard2:27012" },
         { _id: 1, host: "shard2-r1:27016" },
         { _id: 2, host: "shard2-r2:27018" },
         { _id: 3, host: "shard2-r3:27019" }
      ]
   });
   ```
3. Запускаем mongo-sharding-repl\scripts\configsvr\init.sh
4. Запускаем mongo-sharding-repl\scripts\router\init.sh
5. Дальше как в 6,7,8 из mongo-sharding\README.md
   