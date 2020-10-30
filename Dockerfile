# build yata webapp
FROM opensuse/leap:latest AS build
RUN zypper install -y git curl unzip tar which gzip
RUN git clone https://github.com/flutter/flutter
ENV PATH=$PATH:/flutter/bin/
RUN which flutter dart
RUN flutter doctor
RUN flutter channel beta
RUN flutter upgrade
RUN flutter config --enable-web
WORKDIR ./
COPY . .
RUN flutter build web

# serve yata webapp
FROM httpd:2.4
COPY --from=build ./build/web/ /usr/local/apache2/htdocs/
