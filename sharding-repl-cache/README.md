# Задание 4. Шардирование c кэшем 

## шаги для инициализации шардирования и кэширования
1. Поднять ./compose.yaml
2. Выполнить ./scripts/mongo-init.sh
3. Открыть приложениене localhost:8080
4. Наблюдаем json:
```
mongo_topology_type	"Sharded"
mongo_replicaset_name	null
mongo_db	"somedb"
read_preference	"Primary()"
mongo_nodes	
0	
0	"mongos"
1	27017
mongo_primary_host	null
mongo_secondary_hosts	[]
mongo_is_primary	true
mongo_is_mongos	true
collections	
helloDoc	
documents_count	1000
shards	
rs-shard1	"rs-shard1/shard1-a:27018,shard1-b:27018,shard1-c:27018"
rs-shard2	"rs-shard2/shard2-a:27019,shard2-b:27019,shard2-c:27019"
cache_enabled	true
status	"OK"
```
