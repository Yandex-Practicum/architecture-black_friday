.PHONY: up down restart init-config init-shard1 init-shard2 add-shards enable-sharding seed check check-count check-shard1 check-shard2 check-rs1 check-rs2 check-config check-cache init-all

up:
	docker compose up -d

down:
	docker compose down -v

restart:
	docker compose down -v
	docker compose up -d

init-config:
	docker compose exec -T configSrv1 mongosh --port 27019 --quiet --eval 'rs.initiate({_id:"configReplSet",configsvr:true,members:[{_id:0,host:"configSrv1:27019"},{_id:1,host:"configSrv2:27019"},{_id:2,host:"configSrv3:27019"}]})'

init-shard1:
	docker compose exec -T shard1_1 mongosh --port 27018 --quiet --eval 'rs.initiate({_id:"shard1ReplSet",members:[{_id:0,host:"shard1_1:27018"},{_id:1,host:"shard1_2:27018"},{_id:2,host:"shard1_3:27018"}]})'

init-shard2:
	docker compose exec -T shard2_1 mongosh --port 27018 --quiet --eval 'rs.initiate({_id:"shard2ReplSet",members:[{_id:0,host:"shard2_1:27018"},{_id:1,host:"shard2_2:27018"},{_id:2,host:"shard2_3:27018"}]})'

add-shards:
	docker compose exec -T mongos mongosh --port 27017 --quiet --eval 'sh.addShard("shard1ReplSet/shard1_1:27018,shard1_2:27018,shard1_3:27018"); sh.addShard("shard2ReplSet/shard2_1:27018,shard2_2:27018,shard2_3:27018")'

enable-sharding:
	docker compose exec -T mongos mongosh --port 27017 --quiet --eval 'sh.enableSharding("somedb"); db.getSiblingDB("somedb").helloDoc.createIndex({_id:"hashed"}); sh.shardCollection("somedb.helloDoc",{_id:"hashed"})'

seed:
	./scripts/mongo-init.sh

check-count:
	docker compose exec -T mongos mongosh --port 27017 --quiet --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments()'

check-shard1:
	docker compose exec -T shard1_1 mongosh --port 27018 --quiet --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments()'

check-shard2:
	docker compose exec -T shard2_1 mongosh --port 27018 --quiet --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments()'

check-rs1:
	docker compose exec -T shard1_1 mongosh --port 27018 --quiet --eval 'rs.status().members.map(member => ({ name: member.name, stateStr: member.stateStr }))'

check-rs2:
	docker compose exec -T shard2_1 mongosh --port 27018 --quiet --eval 'rs.status().members.map(member => ({ name: member.name, stateStr: member.stateStr }))'

check-config:
	docker compose exec -T configSrv1 mongosh --port 27019 --quiet --eval 'rs.status().members.map(member => ({ name: member.name, stateStr: member.stateStr }))'

check-cache:
	curl -w '\nTime: %{time_total}s\n' -o /dev/null -s http://localhost:8080/helloDoc/users
	curl -w '\nTime: %{time_total}s\n' -o /dev/null -s http://localhost:8080/helloDoc/users
	curl -w '\nTime: %{time_total}s\n' -o /dev/null -s http://localhost:8080/helloDoc/users

check:
	$(MAKE) check-count
	$(MAKE) check-shard1
	$(MAKE) check-shard2
	$(MAKE) check-rs1
	$(MAKE) check-rs2
	$(MAKE) check-config

init-all:
	$(MAKE) up
	sleep 10
	$(MAKE) init-config
	sleep 5
	$(MAKE) init-shard1
	sleep 5
	$(MAKE) init-shard2
	sleep 5
	$(MAKE) add-shards
	$(MAKE) enable-sharding
	$(MAKE) seed
	$(MAKE) check
	$(MAKE) check-cache
