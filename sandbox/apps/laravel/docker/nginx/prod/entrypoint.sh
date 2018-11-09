#!/bin/sh

domain_opts=

openssl dhparam -out /etc/ssl/certs/dhparam.pem 1024

/usr/sbin/crond

# Request a certificate if none was installed before
if [[ ! $(find /etc/letsencrypt/live -name '*.pem') ]] && [[ ! -z "$CERTBOT_DOMAINS" ]]; then
    for d in $CERTBOT_DOMAINS; do
        domain_opts="$domain_opts -d $d"
    done

    certbot certonly -n --standalone $domain_opts --agree-tos -m $ADMIN_EMAIL
fi

nginx -c /etc/nginx/nginx.conf

# /dev/stdout and dev/stderror references to access.log and error.log correspondingly
tail -q -s 10 -f /var/log/nginx/access.log /var/log/nginx/error.log