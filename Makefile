.PHONY: up down logs ps check shell-postgres fernet env

up:
	bash scripts/dev_up.sh

down:
	docker compose down

logs:
	docker compose logs -f

ps:
	docker compose ps

check:
	bash scripts/check_stack.sh

shell-postgres:
	docker compose exec postgres psql -U $$(grep POSTGRES_USER .env | cut -d= -f2) -d $$(grep POSTGRES_DB .env | cut -d= -f2)

fernet:
	bash scripts/generate_fernet_key.sh

env:
	cp -n .env.example .env || true
	@echo "Edit .env — set POSTGRES_PASSWORD, then run: make fernet"
