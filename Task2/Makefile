PROJECT_DIR=mongo-sharding
DC =./$(PROJECT_DIR)/compose.yaml


.PHONY: up
up:
	docker compose -f $(DC) up -d

.PHONY: down
down:
	docker compose -f $(DC) down

.PHONY: logs
logs:
	docker compose -f $(DC) logs -f