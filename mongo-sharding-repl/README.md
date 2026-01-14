# TASK 3

## Как запустить Автоматически

```bash
cd ./mongo-sharding-repl
.\init-sharding.sh
```

## Как запустить Вручную

### 0. переход в директорию

```bash
cd ./mongo-sharding-repl
```

## Как запустить

### 1.Запуск

### 1

```bash
docker compose up -d --build
docker compose ps
```

### 2.1 Config RS (3 ноды)

```bash
docker compose exec -T configsvr1 mongosh --port 27019 --quiet <<'EOF'
try { rs.status(); print("Config RS already initiated"); }
catch(e) {
  rs.initiate({
    _id: "configReplSet",
    configsvr: true,
    members: [
      { _id: 0, host: "configsvr1:27019" },
      { _id: 1, host: "configsvr2:27019" },
      { _id: 2, host: "configsvr3:27019" }
    ]
  })
}
rs.status().ok
EOF
```

### 2.2 Shard1 RS (3 ноды)

```bash
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<'EOF'
try { rs.status(); print("Shard1 RS already initiated"); }
catch(e) {
  rs.initiate({
    _id: "shard1ReplSet",
    members: [
      { _id: 0, host: "shard1-1:27018" },
      { _id: 1, host: "shard1-2:27018" },
      { _id: 2, host: "shard1-3:27018" }
    ]
  })
}
rs.status().ok
EOF
```

### 2.3 Shard2 RS (3 ноды)

```bash
docker compose exec -T shard2-1 mongosh --port 27018 --quiet <<'EOF'
try { rs.status(); print("Shard2 RS already initiated"); }
catch(e) {
  rs.initiate({
    _id: "shard2ReplSet",
    members: [
      { _id: 0, host: "shard2-1:27018" },
      { _id: 1, host: "shard2-2:27018" },
      { _id: 2, host: "shard2-3:27018" }
    ]
  })
}
rs.status().ok
EOF
```

### 2.4 Добавить шарды в кластер через mongos

```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
sh.addShard("shard1ReplSet/shard1-1:27018,shard1-2:27018,shard1-3:27018")
sh.addShard("shard2ReplSet/shard2-1:27018,shard2-2:27018,shard2-3:27018")
sh.status()
EOF
```

### 2.5 Шардирование коллекции + данные

```bash
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
use somedb
db.helloDoc.drop()

sh.enableSharding("somedb")
db.helloDoc.createIndex({ _id: "hashed" })
sh.shardCollection("somedb.helloDoc", { _id: "hashed" })

for (let i = 0; i < 2000; i++) {
  db.helloDoc.insertOne({age:i, name:"ly"+i})
}

print("Total via mongos = " + db.helloDoc.countDocuments())
printjson(db.helloDoc.getShardDistribution())
EOF
```
