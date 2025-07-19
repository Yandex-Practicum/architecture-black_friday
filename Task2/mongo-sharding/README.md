
Запуск с нуля (очистка данных)
```sh
docker compose down -v && docker compose up -d --build
...
```


Пример успешного запуска
```sh
$ docker compose ps -a

NAME                IMAGE                        COMMAND                  SERVICE             CREATED          STATUS                      PORTS
cluster-init        mongo:latest                 "docker-entrypoint.s…"   cluster-init        2 minutes ago    Exited (0) 2 minutes ago
config-init         mongo:latest                 "docker-entrypoint.s…"   config-init         2 minutes ago    Exited (0) 2 minutes ago
configSrv           mongo:latest                 "docker-entrypoint.s…"   configSrv           2 minutes ago    Up 2 minutes (healthy)      27017/tcp
mongo-config-init   mongo:latest                 "docker-entrypoint.s…"   mongo-config-init   26 minutes ago   Created
mongo-init          mongo:latest                 "docker-entrypoint.s…"   mongo-init          13 minutes ago   Exited (0) 13 minutes ago
mongo_init          mongo:latest                 "docker-entrypoint.s…"   mongo_init          34 minutes ago   Created
mongos_router       mongo:latest                 "docker-entrypoint.s…"   mongos_router       2 minutes ago    Up 2 minutes (healthy)      27017/tcp, 27020/tcp
pymongo_api         mongo-sharding-pymongo_api   "uvicorn app:app --h…"   pymongo_api         2 minutes ago    Up 2 minutes                0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp
shard1              mongo:latest                 "docker-entrypoint.s…"   shard1              2 minutes ago    Up 2 minutes (healthy)      27017-27018/tcp
shard1-init         mongo:latest                 "docker-entrypoint.s…"   shard1-init         2 minutes ago    Exited (0) 2 minutes ago
shard2              mongo:latest                 "docker-entrypoint.s…"   shard2              2 minutes ago    Up 2 minutes (healthy)      27017/tcp, 27019/tcp
shard2-init         mongo:latest                 "docker-entrypoint.s…"   shard2-init         2 minutes ago    Exited (0) 2 minutes ago
```

Проверка шардирования
```sh
$ ./scripts/mongo-check-shard1.sh 
Количество документов в shard1: 492

$ ./scripts/mongo-check-shard2.sh
Количество документов в shard1: 508
```
