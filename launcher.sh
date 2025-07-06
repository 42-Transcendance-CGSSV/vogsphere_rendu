#!/bin/bash

COMPOSE_FILE="docker-compose.yml"
DOCKER_COMPOSE="docker compose --file $COMPOSE_FILE"

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
NC="\033[0m"

function help() {
cat <<EOF
Usage: ./launcher.sh [command]

Commands:
  help               Affiche cette aide
  build              Construit et lance les conteneurs
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

  IP_ADDRESS=$(ip addr | awk '/inet / {if (++n==2) print $2}' | cut -d/ -f1)
  sed -i '/^IP=.*/d' .env
  sed -i '/^VITE_IP=.*/d' .env

  export IP=IP_ADDRESS
  echo -e "\nIP=$IP_ADDRESS" >> .env
  echo -e "\nVITE_IP=$IP_ADDRESS" >> .env

  local required_vars=(
    ENVIRONMENT LOG_LEVEL BREVO_API_KEY
    JWT_SECRET IP
  )

  for var in "${required_vars[@]}"; do
    if ! grep -q "^$var=" .env; then
      echo -e "${RED}Missing: $var in .env${NC}"
      exit 1
    fi
  done

  echo -e "${GREEN}Environment variables check passed${NC}"
  echo -e "${YELLOW}Detected IP: ${IP_ADDRESS}${NC}"
}

function setup_ssl() {
  echo -e "${YELLOW}Setting up SSL...${NC}"

  mkdir -p ~/.local/bin/;
  if [ ! -f ~/.local/bin/mkcert ]; then
    curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
    chmod +x mkcert-v*-linux-amd64
    mv mkcert-v*-linux-amd64 ~/.local/bin/mkcert
    grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' ~/.zshrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
    zsh
  fi
  mkdir -p nginx/web_server
  if [ ! -f nginx/web_server/key.pem ] || [ ! -f nginx/web_server/cert.pem ]; then
    mkcert -cert-file nginx/web_server/cert.pem -key-file nginx/web_server/key.pem \
    localhost 127.0.0.1 $(ip addr | awk '/inet / {if (++n==2) print $2}' | cut -d/ -f1) ::1
    echo -e "${GREEN}SSL Certificate generated !${NC}"
  else
    echo -e "${GREEN}SSL Certificate is already present !${NC}"
  fi
  chmod 644 nginx/web_server/key.pem
  chmod 600 nginx/web_server/cert.pem
}

function build() {
  check_env
  setup_ssl
  mkdir -p ~/sgoinfre/ft_transcendence/data/auth_service
  echo -e "${GREEN}Building all services...${NC}"
  export DOCKER_BUILDKIT=1
  $DOCKER_COMPOSE --parallel 27 up --build
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
  set -e  # Exit on error

  CERT_PATH="./nginx/web_server"
  DATA_PATH="$HOME/sgoinfre/ft_transcendence/"

  echo -e "${YELLOW}This will stop containers, prune images, and delete SSL/data files.${NC}"
  read -p "Are you sure you want to continue? [y/N] " confirm
  [[ "$confirm" != "y" && "$confirm" != "Y" ]] && echo "Aborted." && return

  $DOCKER_COMPOSE down -v
  docker builder prune -af
  docker system prune -af

  [ -f "$CERT_PATH/key.pem" ] && rm -f "$CERT_PATH/key.pem"
  [ -f "$CERT_PATH/cert.pem" ] && rm -f "$CERT_PATH/cert.pem"

  [ -d "$DATA_PATH" ] && rm -rf "$DATA_PATH"
  echo -e "${GREEN}Clean completed.${NC}"
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
  *) echo "Commande inconnue: $1."; help ;;
esac
