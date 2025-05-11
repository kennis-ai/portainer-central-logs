#!/bin/bash

set -euo pipefail

# ============================
# Configurações
# ============================
REPO_URL="https://github.com/kennis-ai/portainer-central-logs.git"
REPO_PATH="/tmp/portainer-central-logs"
COMPOSE_PATH="$REPO_PATH/docker-compose.yaml"
LOG_FILE="portainer-deploy.log"

# ============================
# Pré-checagem de dependências
# ============================
for cmd in docker git jq sed curl; do
  if ! command -v $cmd &>/dev/null; then
    echo "Erro: $cmd não está instalado. Por favor, instale antes de continuar."
    exit 1
  fi
done

# ============================
# Logging
# ============================
exec > >(tee -i "$LOG_FILE")
exec 2>&1

# ============================
# Banner
# ============================
clear
cat << "EOF"

██╗  ██╗███████╗███╗   ██╗███╗   ██╗██╗███████╗    ██████╗  █████╗ ████████╗ █████╗      █████╗ ██╗
██║ ██╔╝██╔════╝████╗  ██║████╗  ██║██║██╔════╝    ██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗    ██╔══██╗██║
█████╔╝ █████╗  ██╔██╗ ██║██╔██╗ ██║██║███████╗    ██║  ██║███████║   ██║   ███████║    ███████║██║
██╔═██╗ ██╔══╝  ██║╚██╗██║██║╚██╗██║██║╚════██║    ██║  ██║██╔══██║   ██║   ██╔══██║    ██╔══██║██║
██║  ██╗███████╗██║ ╚████║██║ ╚████║██║███████║    ██████╔╝██║  ██║   ██║   ██║  ██║    ██║  ██║██║
╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝  ╚═══╝╚═╝╚══════╝    ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝    ╚═╝  ╚═╝╚═╝

██████╗  ██████╗ ██████╗ ████████╗ █████╗ ██╗███╗   ██╗███████╗██████╗                             
██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝██╔══██╗██║████╗  ██║██╔════╝██╔══██╗                           
██████╔╝██║   ██║██████╔╝   ██║   ███████║██║██╔██╗ ██║█████╗  ██████╔╝                           
██╔═══╝ ██║   ██║██╔══██╗   ██║   ██╔══██║██║██║╚██╗██║██╔══╝  ██╔══██╗                           
██║     ╚██████╔╝██║  ██║   ██║   ██║  ██║██║██║ ╚████║███████╗██║  ██║                           
╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝                           
                                                                                                 
 ██████╗███████╗███╗   ██╗████████╗██████╗  █████╗ ██╗                                             
██╔════╝██╔════╝████╗  ██║╚══██╔══╝██╔══██╗██╔══██╗██║                                             
██║     █████╗  ██╔██╗ ██║   ██║   ██████╔╝███████║██║                                             
██║     ██╔══╝  ██║╚██╗██║   ██║   ██╔══██╗██╔══██║██║                                             
╚██████╗███████╗██║ ╚████║   ██║   ██║  ██║██║  ██║███████╗                                       
 ╚═════╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝                                       
                                                                                                 
██╗      ██████╗  ██████╗ ███████╗                                                              
██║     ██╔═══██╗██╔════╝ ██╔════╝                                                              
██║     ██║   ██║██║  ███╗███████╗                                                              
██║     ██║   ██║██║   ██║╚════██║                                                              
███████╗╚██████╔╝╚██████╔╝███████║                                                              
╚══════╝ ╚═════╝  ╚═════╝ ╚══════╝                                                              

EOF

# ============================
# Solicita entradas do usuário
# ============================
read -rp "Informe a senha desejada para o admin do Grafana: " GRAFANA_ADMIN_PASSWORD
read -rp "Informe a URL desejada para o Grafana (ex: grafana.exemplo.com): " GRAFANA_URL
if [[ ! "$GRAFANA_URL" =~ ^[a-zA-Z0-9.-]+$ ]]; then
  echo "URL do Grafana inválida. Utilize apenas domínio (ex: grafana.exemplo.com)."
  exit 1
fi

# ============================
# Detecta modo Docker
# ============================
if docker info | grep -q 'Swarm: active'; then
  NETWORK_DRIVER="overlay"
else
  NETWORK_DRIVER="bridge"
fi

# ============================
# Criação de rede
# ============================
if ! docker network ls --format '{{.Name}}' | grep -q '^logging$'; then
  echo "Criando rede Docker 'logging'..."
  if ! docker network create --driver "$NETWORK_DRIVER" logging; then
    echo "Erro ao criar a rede Docker. Abortando."
    exit 1
  fi
else
  echo "Rede 'logging' já existe."
fi

# ============================
# Criação de volumes
# ============================
create_docker_volume() {
  local VOL=$1
  if ! docker volume ls --format '{{.Name}}' | grep -q "^$VOL\$"; then
    echo "Criando volume $VOL..."
    if ! docker volume create "$VOL"; then
      echo "Erro ao criar volume $VOL. Abortando."
      exit 1
    fi
  else
    echo "Volume $VOL já existe."
  fi
}

for VOL in loki_data grafana_data loki_config promtail_config; do
  create_docker_volume "$VOL"
done

# ============================
# Clonagem do repositório
# ============================
echo "Clonando repositório..."
rm -rf "$REPO_PATH"
if ! git clone "$REPO_URL" "$REPO_PATH"; then
  echo "Erro ao clonar o repositório. Abortando."
  exit 1
fi

# ============================
# Cópia de arquivos para volumes
# ============================
copy_to_volume() {
  VOL_NAME=$1
  FILE=$2
  DEST=$(docker volume inspect "$VOL_NAME" -f '{{ .Mountpoint }}')
  echo "Copiando $FILE para $DEST"
  cp "$REPO_PATH/$FILE" "$DEST"
}

copy_to_volume loki_config local-config.yaml
copy_to_volume promtail_config config.yaml

# ============================
# Substituições no docker-compose.yaml
# ============================
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s|^- GF_SECURITY_ADMIN_PASSWORD=.*|- GF_SECURITY_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD|" "$COMPOSE_PATH"
  sed -i '' -E "s|^- traefik\\.http\\.routers\\.grafana\\.rule=.*|- traefik.http.routers.grafana.rule=Host(\`$GRAFANA_URL\`)|" "$COMPOSE_PATH"
else
  sed -i "s|^- GF_SECURITY_ADMIN_PASSWORD=.*|- GF_SECURITY_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD|" "$COMPOSE_PATH"
  sed -i -E "s|^- traefik\\.http\\.routers\\.grafana\\.rule=.*|- traefik.http.routers.grafana.rule=Host(\`$GRAFANA_URL\`)|" "$COMPOSE_PATH"
fi

# ============================
# Pergunta sobre deploy automático
# ============================
read -rp "Deseja fazer o deploy automático da stack via API do Portainer? (s/n): " DEPLOY_CHOICE

if [[ "$DEPLOY_CHOICE" == "s" ]]; then
  read -rp "Usuário admin do Portainer: " PORTAINER_USER
  read -rsp "Senha do Portainer: " PORTAINER_PASS && echo
  read -rp "URL do Portainer (ex: https://portainer.exemplo.com): " PORTAINER_URL
  read -rp "Nome da stack [grafana]: " STACK_NAME
  STACK_NAME=${STACK_NAME:-grafana}

  echo "Realizando login no Portainer..."
  AUTH_RESPONSE=$(curl -sk -w "%{http_code}" -o /tmp/portainer_login.json \
    -X POST "$PORTAINER_URL/api/auth" \
    -H "Content-Type: application/json" \
    -d "{\"Username\": \"$PORTAINER_USER\", \"Password\": \"$PORTAINER_PASS\"}")

  if [[ "$AUTH_RESPONSE" != "200" ]]; then
    echo "Erro no login (HTTP $AUTH_RESPONSE). Abortando."
    cat /tmp/portainer_login.json
    exit 1
  fi

  JWT=$(jq -r .jwt /tmp/portainer_login.json)

  echo "Detectando edição do Portainer..."
  EDITION=$(curl -sk -H "Authorization: Bearer $JWT" "$PORTAINER_URL/api/system/version" | jq -r '.ServerEdition // "CE"')
  echo "Edição detectada: $EDITION"

  ENDPOINT_ID=$(curl -sk -H "Authorization: Bearer $JWT" "$PORTAINER_URL/api/endpoints" | jq '.[0].Id')

  echo "Enviando stack $STACK_NAME para o Portainer..."
  STACK_CONTENT=$(sed 's/\\/\\\\/g' "$COMPOSE_PATH" | sed 's/"/\\"/g' | tr -d '\n')
  curl -sk -X POST "$PORTAINER_URL/api/stacks" \
    -H "Authorization: Bearer $JWT" \
    -H "Content-Type: application/json" \
    -d "{\n      \"Name\": \"$STACK_NAME\",\n      \"EndpointId\": $ENDPOINT_ID,\n      \"SwarmID\": \"\",\n      \"StackFileContent\": \"$STACK_CONTENT\",\n      \"Env\": []\n    }"

  echo "Aguardando os serviços da stack ficarem prontos..."
  until docker service ls | grep -q "$STACK_NAME"; do
    echo -n "."
    sleep 5
  done

  echo -e "\nStack implantada com sucesso."
  docker service ls | grep "$STACK_NAME"

  echo "Criando datasource Loki no Grafana..."
  GRAFANA_HOST="https://$GRAFANA_URL"
  curl -sk -u "admin:$GRAFANA_ADMIN_PASSWORD" "$GRAFANA_HOST/api/datasources" \
    -H "Content-Type: application/json" \
    -d "{\n      \"name\": \"Loki\",\n      \"type\": \"loki\",\n      \"access\": \"proxy\",\n      \"url\": \"http://loki:3100\",\n      \"basicAuth\": false,\n      \"isDefault\": true\n    }"
  echo "Datasource Loki criada com sucesso."
else
  echo -e "\n==== Copie o conteúdo abaixo e cole na interface do Portainer (Stacks) ===="
  cat "$COMPOSE_PATH"
  echo -e "\n==== Fim do docker-compose.yaml ===="
fi
