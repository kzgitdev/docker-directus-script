# create ,compose and  boot up docker container of Astro, Directus and Database.

## description
generate-env.sh shell script is to auto generate following files and directory.
- .env  
- astro.dockerfile  
- directus.dockerfile  
- docker-compose.yml  
- astro/  ... empty dirctory
- directus/{controllers,extensions,uploads,services} ... empty dirctory
- database/ ... empty directory

## build container and boot it up
1. step1  set to execute permission  
```chmod +x ./generate-env.sh```

2. step2: run the generate-env.sh  
```./generate-env.sh```

3. step3: access the admin page at strapi-app container  
http://localhost:1337/admin

4. step4: access the astro page at astro-app contaner  
http://localhost