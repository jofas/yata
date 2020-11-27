all:
	docker build -t yata_fronend_webapp --no-cache ./frontend/
	docker build -t yata_api --no-cache ./api/
	docker build -t keycloak_proxy --no-cache ./keycloak_proxy/
	mkdir -p volumes/keycloak
	mkdir -p volumes/mongo
