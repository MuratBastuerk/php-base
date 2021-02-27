#!/bin/bash
set -e

#used in aws fargate
if [[ "$@" =~ "--with-artisan-migrate" ]]; then
    # sleep a little to wait for postgres
    sleep 4
    CMD="php artisan migrate"
    echo "Running '$CMD' .."
    $CMD
    set -- ${@/--with-artisan-migrate/}
fi

#used for local development
if [[ "$@" =~ "--with-migrate-and-seeds" ]]; then
    # sleep a little to wait for postgres
    sleep 4
    CMD="php artisan migrate --seed"
    echo "Running '$CMD' .."
    $CMD
    set -- ${@/--with-migrate-and-seeds/}
fi

if [ "${1#-}" != "$1" ]; then
  set -- /usr/bin/supervisord -n -c /etc/supervisord.conf "$@"
fi

if [ -z "$1" ]; then
    set -- /usr/bin/supervisord -n -c /etc/supervisord.conf
fi

exec "$@"