# Base image for web development with PHP

- Alpine 3.12
- PHP 7.4.14 with:
  - Composer
  - Lumen 8
  - Swagger
  - OPCache
  - Xdebug 2.98
- Nginx
  - HTTPs enabled
  - with self signed cert
    - add your own certs:
      `ADD dockerconf/cert/site.crt /etc/nginx/ssl/site.crt`
      `ADD dockerconf/cert/site.key /etc/nginx/ssl/site.key`
  - root is: `/var/www/html`
- Cron 
- Git
- Supervisor
- ca-certificate for cerfiticate management
