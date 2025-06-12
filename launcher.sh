#!/bin/bash

COMPOSE_FILE="docker-compose.yml"
DOCKER_COMPOSE="docker compose -f $COMPOSE_FILE"
DOCKER_BUILDKIT="DOCKER_BUILDKIT=1"
COMPOSE_DOCKER_CLI_BUILD="COMPOSE_DOCKER_CLI_BUILD=1"

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
NC="\033[0m"

function help() {
cat <<EOF
Usage: ./dev.sh [command]

Commands:
  help               Affiche cette aide
  build [service]    Construit les conteneurs (ou un service)
  up                 Démarre les conteneurs (foreground)
  down               Arrête et supprime tous les conteneurs
  stop               Arrête tous les conteneurs
  restart [service]  Redémarre les conteneurs
  logs [service]     Affiche les logs
  ps                 Liste les conteneurs
  clean              Nettoie les volumes, images, certifs, tokens
  setup-ssl          Génère les certificats SSL
  setup-env          Génère les tokens dans .env
  rebuild            Reconstruit et démarre
EOF
}

function check_env() {
  echo -e "${YELLOW}Checking environment variables...${NC}"
  if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
  fi

  local required_vars=(
    BACKEND_SECRET_KEY JWT_SECRET_KEY TEMPORARY_JWT_SECRET_KEY PYTHONUNBUFFERED
    VITE_CLIENT_ID VITE_CLIENT_SECRET SUPERUSER_USERNAME SUPERUSER_EMAIL
    SUPERUSER_PASSWORD DB_NAME DB_USER DB_PASSWORD
  )

  for var in "${required_vars[@]}"; do
    if ! grep -q "^$var=" .env; then
      echo -e "${RED}Missing: $var in .env${NC}"
      exit 1
    fi
  done

  echo -e "${GREEN}Environment variables check passed${NC}"
}

function setup_ssl() {
  echo -e "${YELLOW}Setting up SSL...${NC}"
  mkdir -p nginx/web_server
  if [ ! -f nginx/web_server/ft_transcendence.crt ] || [ ! -f nginx/web_server/ft_transcendence.key ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout nginx/web_server/ft_transcendence.key -out nginx/web_server/ft_transcendence.crt \
      -subj "/C=FR/ST=AURA/L=Lyon/O=42/OU=Ft_transcendence/CN=127.0.0.1"
  fi
  chmod 644 nginx/web_server/ft_transcendence.crt
  chmod 600 nginx/web_server/ft_transcendence.key
}

function setup_env() {
  IP_ADDRESS=$(ip addr | awk '/inet / {if (++n==2) print $2}' | cut -d/ -f1)
  echo -e "${YELLOW}Detected IP: ${IP_ADDRESS}${NC}"

  GAME_TOKEN=$(openssl rand -hex 32)

  sed -i '/^AI_SERVICE_TOKEN/d;/^GAME_SERVICE_TOKEN/d;/^VITE_REDIRECT_URI/d' .env

  echo "GAME_SERVICE_TOKEN=Bearer $GAME_TOKEN" >> .env
  echo "VITE_REDIRECT_URI=https://$IP_ADDRESS:7777/auth/authfortytwo" >> .env

}

function build() {
  check_env
  setup_ssl
  setup_env
  if [ "$1" ]; then
    echo -e "${GREEN}Building $1...${NC}"
    $DOCKER_BUILDKIT $COMPOSE_DOCKER_CLI_BUILD $DOCKER_COMPOSE build "$1"
  else
    echo -e "${GREEN}Building all services...${NC}"
    $DOCKER_BUILDKIT $COMPOSE_DOCKER_CLI_BUILD $DOCKER_COMPOSE build
  fi
}

function up() {
  check_env
  $DOCKER_COMPOSE up
}

function down() {
  $DOCKER_COMPOSE down
}

function stop() {
  $DOCKER_COMPOSE stop
}

function restart() {
  if [ "$1" ]; then
    $DOCKER_COMPOSE restart "$1"
  else
    $DOCKER_COMPOSE restart
  fi
}

function logs() {
  if [ "$1" ]; then
    $DOCKER_COMPOSE logs -f "$1"
  else
    $DOCKER_COMPOSE logs -f
  fi
}

function ps_containers() {
  $DOCKER_COMPOSE ps
}

function clean() {
  down
  docker builder prune -f
  $DOCKER_COMPOSE down -v
  rm -rf ssl
  sed -i '/AI_SERVICE_TOKEN/d;/GAME_SERVICE_TOKEN/d;/VITE_REDIRECT_URI/d' .env
}


function rebuild() {
  setup_ssl
  setup_env
  if [ "$1" ]; then
    $DOCKER_COMPOSE up --build "$1"
  else
    $DOCKER_COMPOSE up --build
  fi
}

# Dispatcher
case "$1" in
  help|"") help ;;
  build) shift; build "$@" ;;
  build-fast) shift; build_fast "$@" ;;
  up) up ;;
  up-fg) up_fg ;;
  down) down ;;
  stop) stop ;;
  restart) shift; restart "$@" ;;
  logs) shift; logs "$@" ;;
  ps) ps_containers ;;
  clean) clean ;;
  setup-ssl) setup_ssl ;;
  setup-env) setup_env ;;
  update-hashes) update_hashes ;;
  rebuild) shift; rebuild "$@" ;;
  rebuild-fast) shift; rebuild_fast "$@" ;;
  rebuild-fg) shift; rebuild_fg "$@" ;;
  *) echo "Commande inconnue: $1. Tapez ./dev.sh help" ;;
esac
