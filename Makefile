all: frontend yata_api keycloak_proxy volumes

frontend:
	docker build -t yata_fronend_webapp ./frontend/

yata_api:
	docker build -t yata_api ./api/

keycloak_proxy:
	docker build -t keycloak_proxy ./keycloak_proxy/

volumes:
	mkdir -p volumes/keycloak
	mkdir -p volumes/mongo

run:
	docker-compose -f docker-compose.yml up

run_debug:
	bash -c "source .env_debug ; docker-compose -f docker-compose-debug.yml up"

run_debug_api:
	bash -c "source .env_debug ; cargo run --manifest-path api/Cargo.toml"

run_debug_keycloak_proxy:
	bash -c "source .env_debug ; cargo run --manifest-path keycloak_proxy/Cargo.toml"

run_debug_frontend:
	bash -c "cd frontend ; flutter run -d chrome --web-port 8000"
