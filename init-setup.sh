#!/bin/bash

sudo rm -rf database* directus* astro* .env *.dockerfile docker-compose.yml

docker image prune -f
docker builder prune -f
docker volume prune -f

docker rmi directus-app:latest
docker rmi postgres-custom:latest
docker rmi astro-app:latest
