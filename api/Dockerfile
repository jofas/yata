FROM rust:1.45.2 AS build
COPY . .
RUN cargo build --release

FROM opensuse/leap:latest
COPY --from=build ./target/release/yata_api ./
CMD ./yata_api
