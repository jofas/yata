FROM rust:1.45.2 AS build
COPY . .
RUN echo $KEYCLOAK_PROXY_PORT
RUN cargo build --release

FROM opensuse/leap:latest
COPY --from=build ./target/release/keycloak_proxy ./
CMD ./keycloak_proxy
