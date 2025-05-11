#!/bin/bash

set -euo pipefail

DEBUG_MODE=false
DRY_RUN=false

if [[ "${1:-}" == "debug" ]]; then
  DEBUG_MODE=true
  echo "[DEBUG] Modo de depuração ativado."
elif [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[DRY-RUN] Nenhuma ação será realmente executada."\else
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
fi

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
  STACK_MODE="swarm"
else
  NETWORK_DRIVER="bridge"
  STACK_MODE="standalone"
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
# Adicionar debug para verificar se as substituições estão funcionando
echo "Aplicando substituições no docker-compose.yaml..."

if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s|{GRAFANA_ADMIN_PASSWORD}|$GRAFANA_ADMIN_PASSWORD|g" "$COMPOSE_PATH"
  sed -i '' "s|{grafana_url_here}|$GRAFANA_URL|g" "$COMPOSE_PATH"
else
  sed -i "s|{GRAFANA_ADMIN_PASSWORD}|$GRAFANA_ADMIN_PASSWORD|g" "$COMPOSE_PATH"
  sed -i "s|{grafana_url_here}|$GRAFANA_URL|g" "$COMPOSE_PATH"
fi

# Verificar se as substituições foram feitas
echo "Verificando substituições..."
grep -n "GRAFANA_ADMIN_PASSWORD\|grafana_url_here" "$COMPOSE_PATH" || echo "Substituições aplicadas com sucesso."

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

# ============================
# Obter SwarmID (necessário para modo swarm)
# ============================
if [[ "$STACK_MODE" == "swarm" ]]; then
  echo "Obtendo SwarmID..."
  
  # Método 1: Tentar obter via API do Portainer
  SWARM_INFO=$(curl -sk -H "Authorization: Bearer $JWT" "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/swarm")
  SWARM_ID=$(echo "$SWARM_INFO" | jq -r '.ID // empty')
  
  # Método 2: Se não conseguir via API, usar docker diretamente
  if [[ -z "$SWARM_ID" ]]; then
    echo "Obtendo SwarmID via comando docker..."
    SWARM_ID=$(docker info --format '{{.Swarm.Cluster.ID}}' 2>/dev/null || echo "")
  fi
  
  # Verificar se conseguimos obter o SwarmID
  if [[ -z "$SWARM_ID" ]]; then
    echo "Erro: Não foi possível obter o SwarmID. Verifique se o Swarm está ativo."
    exit 1
  fi
  
  echo "SwarmID encontrado: $SWARM_ID"
else
  SWARM_ID=""
fi


# ============================
# Enviando stack para o Portainer
# ============================
echo "Enviando stack $STACK_NAME para o Portainer (modo: $STACK_MODE)..."

if $DRY_RUN; then
  echo "[DRY-RUN] Comando de envio da stack (simulado)."
  echo "Modo: $STACK_MODE"
  echo "Compose file: $COMPOSE_PATH"
  echo "Endpoint ID: $ENDPOINT_ID"
  echo "SwarmID: $SWARM_ID"
  echo "Portainer URL: $PORTAINER_URL"
  echo "Stack Name: $STACK_NAME"
  exit 0
fi

# Criar um arquivo temporário com o JSON válido
cat > /tmp/stack_payload.json << EOF
{
  "name": "$STACK_NAME",
  "stackFileContent": $(jq -Rs . < "$COMPOSE_PATH"),
  "swarmID": "$SWARM_ID",
  "fromAppTemplate": false,
  "env": []
}
EOF

# Enviar o payload usando o arquivo temporário
STACK_RESPONSE=$(curl -sk -w "%{http_code}" -o /tmp/portainer_stack.json \
  -X POST "$PORTAINER_URL/api/stacks/create/$STACK_MODE/string?endpointId=$ENDPOINT_ID" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d @/tmp/stack_payload.json)

if [[ "$STACK_RESPONSE" != "200" && "$STACK_RESPONSE" != "201" ]]; then
  echo "Erro ao criar stack (HTTP $STACK_RESPONSE)."
  echo "Payload enviado:"
  cat /tmp/stack_payload.json
  echo "Resposta do servidor:"
  cat /tmp/portainer_stack.json
  exit 1
fi

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
