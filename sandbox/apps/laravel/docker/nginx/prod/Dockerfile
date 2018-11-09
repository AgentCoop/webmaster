FROM nginx:1.13.12-alpine

RUN apk add --no-cache --virtual .persistent-deps \
    openssl \
    certbot

# Cron job for the SSL certificate renewal
RUN set -ex \
    && crontab -l | { cat; echo "59 23 * * * certbot renew --standalone --pre-hook 'nginx -s stop' --post-hook 'nginx -c /etc/nginx/nginx.conf'"; } | crontab -

COPY ./sites-enabled/app.conf /etc/nginx/conf.d/default.conf
COPY ./ssl-params.conf /etc/nginx/conf.d/
COPY nginx.conf /etc/nginx/
COPY entrypoint.sh /

RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
