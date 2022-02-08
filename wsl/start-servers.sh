#!/bin/sh

. /lib/lsb/init-functions

echo 'Starting PostgreSQL'
sudo service postgresql start

echo 'Starting NATS.io'
sudo start-stop-daemon --start --quiet --background --pidfile /var/run/nats.pid --make-pidfile --exec /usr/local/bin/nats-server

echo 'Starting Vault'
sudo start-stop-daemon --start --quiet --background --pidfile /var/run/vault.pid --make-pidfile --exec /usr/bin/vault -- server -dev -dev-root-token-id=myroot
