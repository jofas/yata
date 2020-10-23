# Dockerfile for serving this app build for web
FROM httpd:2.4
COPY ./build/web/ /usr/local/apache2/htdocs/
