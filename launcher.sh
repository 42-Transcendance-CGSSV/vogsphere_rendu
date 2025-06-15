#!/bin/bash

COMPOSE_FILE="docker-compose.yml"
DOCKER_COMPOSE="docker compose --file $COMPOSE_FILE"

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
EOF
}

function check_env() {
  echo -e "${YELLOW}Checking environment variables...${NC}"
  if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
  fi

  local required_vars=(
    ENVIRONMENT LOG_LEVEL BREVO_API_KEY
    JWT_SECRET
  )

  for var in "${required_vars[@]}"; do
    if ! grep -q "^$var=" .env; then
      echo -e "${RED}Missing: $var in .env${NC}"
      exit 1
    fi
  done

  echo -e "${GREEN}Environment variables check passed${NC}"
  IP_ADDRESS=$(ip addr | awk '/inet / {if (++n==2) print $2}' | cut -d/ -f1)
  echo -e "${YELLOW}Detected IP: ${IP_ADDRESS}${NC}"
}

function setup_ssl() {
  echo -e "${YELLOW}Setting up SSL...${NC}"
  mkdir -p nginx/web_server
  if [ ! -f nginx/web_server/ft_transcendence.crt ] || [ ! -f nginx/web_server/ft_transcendence.key ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout nginx/web_server/ft_transcendence.key -out nginx/web_server/ft_transcendence.crt \
      -subj "/C=FR/ST=AURA/L=Lyon/O=42/OU=Ft_transcendence/CN=127.0.0.1"
    echo -e "${GREEN}SSL Certificate generated !${NC}"
  else
    echo -e "${GREEN}SSL Certificate is already present !${NC}"
  fi
  chmod 644 nginx/web_server/ft_transcendence.crt
  chmod 600 nginx/web_server/ft_transcendence.key
}

function build() {
  check_env
  setup_ssl
  mkdir -p ~/sgoinfre/ft_transcendence/data/auth_service
  if [ "$1" ]; then
    echo -e "${GREEN}Building $1...${NC}"
    $DOCKER_COMPOSE up --build "$1"
  else
    echo -e "${GREEN}Building all services...${NC}"
    $DOCKER_COMPOSE up --build
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
  rm -rf nginx/web_server/ft_transcendence.crt && rm -rf nginx/web_server/ft_transcendence.key
  sleep 2
  rm -rf ~/sgoinfre/ft_transcendence/data/auth_service/
}

# Dispatcher
case "$1" in
  help|"") help ;;
  build) shift; build "$@" ;;
  up) up ;;
  down) down ;;
  stop) stop ;;
  restart) shift; restart "$@" ;;
  logs) shift; logs "$@" ;;
  ps) ps_containers ;;
  clean) clean ;;
  setup-ssl) setup_ssl ;;
  check-env) check_env ;;
  rebuild) shift; rebuild "$@" ;;
  *) echo "Commande inconnue: $1. Tapez ./launcher.sh help" ;;
esac
