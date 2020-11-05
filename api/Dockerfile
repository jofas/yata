FROM rust:latest AS build
COPY . .
RUN cargo build --release

FROM opensuse/leap:latest
COPY --from=build ./target/release/yata_api ./
RUN ls
CMD ./yata_api
