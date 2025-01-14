# I use Alpine Linux docker image
#   docker image: directus/directus:latest / OS: Alpine Linux 3.20 / directus v11.1.1 / node:1000:1000:sh / npm 10.7.0 / yarn 1.22.19
USERID=$(id -u)
GROUPID=$(id -g)
DIRECTUS_PORT=8055
DIRECTUS_DATA="./directus"
DATABASE_DIR="./database"
ASTRO_DIR="./astro"

cat <<EOF > .env
# created_at: $(date +%Y/%m/%d) $(date +%H:%M:%S)
# generated by generate-env.sh
USERID=${USERID}
GROUPID=${GROUPID}
EOF

# create Dockerfile: directus.dockerfile
cat <<EOF > directus.dockerfile
# syntax=docker/dockerfile:1
# created_at: $(date +%Y/%m/%d) $(date +%H:%M:%S)
# generated by generate-env.sh
FROM directus/directus:latest AS build

# install packages
#   shadow: to use usermod, groupmod
#   bash: bash(Alpine Linux default shell: sh)
USER root
RUN apk upgrade --update-cache && apk add openssl bash shadow git && rm -rf /var/cache/apk/*

WORKDIR /directus

RUN groupmod -g ${GROUPID} node && usermod -u ${USERID} node && usermod -s /bin/bash node && chown -R node:node /directus

USER node
EOF

# create Dockerfile: postgres.dockerfile
#   docker image: postgres:17.0-alpine3.20 / OS:Alpine Linux 3.20 / postgres 17.0 / postgres:x:70:70:/bin/sh
cat <<EOF > postgres.dockerfile
# syntax=docker/dockerfile:1
# created_at: $(date +%Y/%m/%d) $(date +%H:%M:%S)
# generated by generate-env.sh
FROM postgres:17.0-alpine3.20 AS build

# install packages
#   shadow: to use usermod, groupmod
#   bash: bash(Alpine Linux default shell: sh)
USER root
RUN apk upgrade --update-cache && apk add openssl bash shadow git && rm -rf /var/cache/apk/*

WORKDIR /var/lib/postgres

RUN groupmod -g ${GROUPID} postgres && usermod -u ${USERID} postgres && usermod -s /bin/bash postgres

USER postgres
EOF

# create Dockerfile: astro.dockerfile
#   docker image: node:22.10.0-alpine3.20 / OS: Alpine Linux 3.20 / node:x:1000:1000:bin/sh
cat <<EOF > astro.dockerfile
# syntax=docker/dockerfile:1
FROM node:22.10.0-alpine3.20

RUN apk upgrade --update-cache && \
    apk add openssl bash shadow && \
    rm -rf /var/cache/apk/*

WORKDIR /src

RUN groupmod -g 1002 node && \
    usermod -u 1002 node && \
    chown -R node:node /src

USER node
EOF

# create docker-compose.yml
cat <<EOF > docker-compose.yml
# created_at: $(date +%Y/%m/%d) $(date +%H:%M:%S)
# generated by generate-env.sh
services:
  database:
    image: postgres-custom:latest
    environment:
      TZ: "Asia/Tokyo"
      POSTGRES_USER: "directus"
      POSTGRES_PASSWORD: "directus"
      POSTGRES_DB: "directus"
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
      - ./database:/var/lib/postgres
    healthcheck:
      test: ["CMD", "pg_isready", "--host=localhost", "--username=directus"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_interval: 5s
      start_period: 30s

  # cache:
  #   image: redis:6
  #   healthcheck:
  #     test: ["CMD-SHELL", "[ $$(redis-cli ping) = 'PONG' ]"]
  #     interval: 10s
  #     timeout: 5s
  #     retries: 5
  #     start_interval: 5s
  #     start_period: 30s

  directus:
    image: directus-app:latest
    container_name: directus-app
    ports:
      - "${DIRECTUS_PORT}:8055"
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
      - ${DIRECTUS_DATA}/database:/directus/database
      - ${DIRECTUS_DATA}/extensions:/directus/extensions
      - ${DIRECTUS_DATA}/uploads:/directus/uploads
      - ${DIRECTUS_DATA}/templates:/directus/templates
    depends_on:
      database:
        condition: service_healthy
      # cache:
      #   condition: service_healthy
    environment:
      SECRET: "replace-with-secure-random-value"

      DB_CLIENT: "pg"
      DB_HOST: "database"
      DB_PORT: "5432"
      DB_DATABASE: "directus"
      DB_USER: "directus"
      DB_PASSWORD: "directus"
      CACHE_ENABLED: "false"
      CACHE_STORE: "memory"
      CACHE_AUTO_PURGE: "true"
      # CACHE_STORE: "redis"
      # REDIS: "redis://cache:6379"

      ADMIN_EMAIL: "admin@example.com"
      ADMIN_PASSWORD: "d1r3ctu5"

      # Make sure to set this in production
      # (see https://docs.directus.io/self-hosted/config-options#general)
      # PUBLIC_URL: "https://directus.example.com"

  astro:
    image: astro-app:latest
    container_name: astro-app
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
      - ./astro:/src
    ports:
      - "80:3000"
    command: "npm run dev -- --host 0.0.0.0 --port 3000"
    stdin_open: true
    tty: true

EOF

# create docker image: directus-app:latest from directus.dockerfile
#   execute docker build command
echho "-----"
echo "create directus-app:latest docker image ...."
docker build --no-cache -t directus-app:latest -f directus.dockerfile .

# create database/
if [ ! -e ${DATABASE_DIR} ]; then
  mkdir ${DATABASE_DIR}
else
  echo "${DATABASE_DIR} is existed and renamed ${DATABASE_DIR}-YYYYMMDD-HHSSMM"
  mv ${DATABASE_DIR} ${DATABASE_DIR}-$(date +%Y%m%d-%H%M%S)
  mkdir ${DATABASE_DIR}
fi

if [ ! -e ${DIRECTUS_DATA} ]; then
    mkdir -p ./${DIRECTUS_DATA}/{database,extensions,uploads,templates}
    echo "-----"
    echo "./${DIRECTUS_DATA}/{database,extensions,uploads,templates} is created."
else
    echo "-----"
    echo "${DIRECTUS_DATA} directory is arleady existed and renamed"
    mv ${DIRECTUS_DATA} ${DIRECTUS_DATA}-$(date +%Y%m%d-%H%M%S)
    mkdir -p ./${DIRECTUS_DATA}/{database,extensions,uploads,templates}
fi
docker image ls | grep directus

# create docker image: postgres-custom:latest from postgres:17.0-alpine3.20
echho "-----"
echo "create postgres-custom:latest docker image ...."
docker build --no-cache -t postgres-custom:latest -f postgres.dockerfile .
docker image ls | grep postgres

# create astro/
if [ ! -e ${ASTRO_DIR} ]; then
  mkdir ${ASTRO_DIR}
else
  echo "${ASTRO_DIR} is existed and renamed ${ASTRO_DIR}-YYYYMMDD-HHSSMM"
  mv ${ASTRO_DIR} ${ASTRO_DIR}-$(date +%Y%m%d-%H%M%S)
  mkdir ${ASTRO_DIR}
fi

# create docker image: astro-app:latest from node:22.10.0-alpine3.20
docker build -t astro-app:latest -f astro.dockerfile .

# install astro framework in 
echo "-----"
echo "Now installing astro ...."
docker compose run --rm astro npm create astro@latest /src --no-run
echo "Successfully! Astro is installed!"

docker compose up -d 

echo "access to admin login page in directus: http://localhost:${DIRECTUS_PORT}/admin or http://localhost:${DIRECTUS_PORT}"
echo "access the astro homepage: http://localhost"
