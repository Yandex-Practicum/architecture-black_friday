PROJECT_DIR=mongo-sharding-repl
DC_INFRA=./$(PROJECT_DIR)/compose_infra.yaml
DC_MONGO=./$(PROJECT_DIR)/compose_mongo.yaml
DC_MONGO_INIT=./$(PROJECT_DIR)/compose_mongo_init.yaml
DC_APP=./$(PROJECT_DIR)/compose_app.yaml


.PHONY: up
up:
	docker compose -f $(DC_INFRA) -f $(DC_MONGO) -f $(DC_MONGO_INIT) -f $(DC_APP) up -d

.PHONY: down
down:
	docker compose -f $(DC_INFRA) -f $(DC_MONGO) -f $(DC_MONGO_INIT) -f $(DC_APP) down

.PHONY: logs
logs:
	docker compose -f $(DC_INFRA) -f $(DC_MONGO) -f $(DC_MONGO_INIT) -f $(DC_APP) logs -f