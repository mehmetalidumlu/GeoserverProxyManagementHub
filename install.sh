#!/bin/sh
# Installs or updates GSPMH with Docker Compose.
#   ./install.sh          GSPMH
#   ./install.sh --vpn    GSPMH with VPN tunnels (gives the API access to the Docker socket)
# The first run writes .env with random passwords and keys; later runs keep it and update the images.
set -eu
cd "$(dirname "$0")"

command -v docker >/dev/null 2>&1 || { echo "Docker is not installed: https://docs.docker.com/engine/install/"; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "Docker Compose v2 is required (docker compose)."; exit 1; }

random() { LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$1"; }

if [ ! -f .env ]; then
  cp .env.example .env
  sed -i.bak \
    -e "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$(random 32)|" \
    -e "s|^JWT_SECRET_KEY=.*|JWT_SECRET_KEY=$(random 64)|" \
    -e "s|^ENCRYPTION_KEY=.*|ENCRYPTION_KEY=$(random 48)|" .env
  if [ -S /var/run/docker.sock ]; then
    gid=$(stat -c %g /var/run/docker.sock 2>/dev/null || echo 999)
    sed -i.bak -e "s|^DOCKER_GID=.*|DOCKER_GID=$gid|" .env
  fi
  rm -f .env.bak
  chmod 600 .env
  echo ".env created with random passwords and keys. Keep a copy of it in a safe place."
fi

files="-f docker-compose.yml"
[ "${1:-}" = "--vpn" ] && files="$files -f docker-compose.vpn.yml"

docker compose $files pull
docker compose $files up -d

port=$(grep -E '^WEB_PORT=' .env | cut -d= -f2)
echo
echo "GSPMH is starting. Open http://$(hostname -f 2>/dev/null || hostname):${port:-80} and complete the setup wizard."
