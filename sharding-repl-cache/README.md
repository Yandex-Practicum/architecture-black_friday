# pymongo-api

## Как запустить

1. Переходим в папку sharding-repl-cache
```shell
cd sharding-repl-cache
```

2. Запускаем mongodb, redis и приложение

```shell
docker compose up -d
```

3. Инициализируем mongodb данными   

```shell
./scripts/init.sh
```

4. Запустить приложение и этим закешировать данные в redis  
Откройте в браузере http://localhost:8080/helloDoc/users   

## Как проверить

Откройте в браузере http://localhost:8080/helloDoc/users - Второй и последующие вызовы должны выполнятся <100мс.  
Можно наблюдать, что кэш включен в pymongo-api  
![Включенный кэш в pymongo](screens/check_pymongo_cached.png)  

## Проверка на уровне Redis:  
docker exec -it redis redis-cli INFO STATS  

Статистика redis до вызова запроса http://localhost:8080/helloDoc/users в приложении:  
![Незадействованный redis](screens/check_redis_before.png)  

Статистика redis после вызова запроса http://localhost:8080/helloDoc/users в приложении:  
![Применённый redis](screens/check_redis_after.png)  

