all:
	docker build -t yata_fronend_webapp ./frontend/
	docker build -t yata_api ./api/
	docker build -t keycloak_proxy ./keycloak_proxy/
	mkdir -p volumes/keycloak
	mkdir -p volumes/mongo
