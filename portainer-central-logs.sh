#!/bin/bash

set -euo pipefail

DEBUG_MODE=false
DRY_RUN=false
CONFIG_FILE=""

# ============================
# Parse de argumentos
# ============================
for arg in "$@"; do
  case $arg in
    debug)
      DEBUG_MODE=true
      echo "[DEBUG] Modo de depuração ativado."
      ;;
    --dry-run)
      DRY_RUN=true
      echo "[DRY-RUN] Nenhuma ação será realmente executada."
      ;;
    --config=*)
      CONFIG_FILE="${arg#*=}"
      echo "Usando arquivo de configuração: $CONFIG_FILE"
      ;;
    --help|-h)
      echo "Uso: $0 [debug] [--dry-run] [--config=arquivo]"
      echo "  debug       - Ativa modo de depuração"
      echo "  --dry-run   - Simula sem executar"
      echo "  --config=   - Usa arquivo de configuração"
      exit 0
      ;;
  esac
done

if [[ "$DEBUG_MODE" == "false" && "$DRY_RUN" == "false" && -z "$CONFIG_FILE" ]]; then
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
# Função para carregar configuração
# ============================
load_config() {
  if [[ -n "$CONFIG_FILE" ]]; then
    if [[ ! -f "$CONFIG_FILE" ]]; then
      echo "Erro: Arquivo de configuração não encontrado: $CONFIG_FILE"
      echo "Criando arquivo de exemplo..."
      create_example_config
      exit 1
    fi
    
    echo "Carregando configuração de $CONFIG_FILE..."
    source "$CONFIG_FILE"
    
    # Validar se todas as variáveis necessárias foram carregadas
    local required_vars=("GRAFANA_ADMIN_PASSWORD" "GRAFANA_URL" "DEPLOY_CHOICE")
    if [[ "$DEPLOY_CHOICE" == "s" ]]; then
      required_vars+=("PORTAINER_USER" "PORTAINER_PASS" "PORTAINER_URL" "STACK_NAME")
    fi
    
    for var in "${required_vars[@]}"; do
      if [[ -z "${!var:-}" ]]; then
        echo "Erro: Variável $var não definida no arquivo de configuração."
        exit 1
      fi
    done
  else
    # Solicita entradas do usuário
    read -rp "Informe a senha desejada para o admin do Grafana: " GRAFANA_ADMIN_PASSWORD
    read -rp "Informe a URL desejada para o Grafana (ex: grafana.exemplo.com): " GRAFANA_URL
    if [[ ! "$GRAFANA_URL" =~ ^[a-zA-Z0-9.-]+$ ]]; then
      echo "URL do Grafana inválida. Utilize apenas domínio (ex: grafana.exemplo.com)."
      exit 1
    fi
    
    read -rp "Deseja fazer o deploy automático da stack via API do Portainer? (s/n): " DEPLOY_CHOICE
    
    if [[ "$DEPLOY_CHOICE" == "s" ]]; then
      read -rp "Usuário admin do Portainer: " PORTAINER_USER
      read -rsp "Senha do Portainer: " PORTAINER_PASS && echo
      read -rp "URL do Portainer (ex: https://portainer.exemplo.com): " PORTAINER_URL
      read -rp "Nome da stack [grafana]: " STACK_NAME
      STACK_NAME=${STACK_NAME:-grafana}
    fi
  fi
}

# ============================
# Criar arquivo de configuração de exemplo
# ============================
create_example_config() {
  cat > "portainer-config.example" << 'EOF'
# Configuração para deploy do Portainer Central Logs
# Copie este arquivo para 'portainer-config.conf' e edite os valores

# Configurações do Grafana
GRAFANA_ADMIN_PASSWORD="sua_senha_aqui"
GRAFANA_URL="grafana.exemplo.com"

# Deploy automático?
DEPLOY_CHOICE="s"  # s para sim, n para não

# Se DEPLOY_CHOICE="s", configure os parâmetros abaixo:
PORTAINER_USER="admin"
PORTAINER_PASS="sua_senha_do_portainer"
PORTAINER_URL="https://portainer.exemplo.com"
STACK_NAME="grafana"

# Configurações avançadas (opcional)
# SWARM_ID="" # Se você souber o SwarmID específico, defina aqui
EOF
  echo "Arquivo de exemplo criado: portainer-config.example"
  echo "Copie para 'portainer-config.conf' e edite com seus valores."
}

# ============================
# Carregar configuração
# ============================
load_config

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

echo "Modo Docker detectado: $STACK_MODE"

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
echo "Aplicando substituições no docker-compose.yaml..."

if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s|{GRAFANA_ADMIN_PASSWORD}|$GRAFANA_ADMIN_PASSWORD|g" "$COMPOSE_PATH"
  sed -i '' "s|{grafana_url_here}|$GRAFANA_URL|g" "$COMPOSE_PATH"
  sed -i '' "s|^      - GF_SECURITY_ADMIN_PASSWORD=.*|      - GF_SECURITY_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD|" "$COMPOSE_PATH"
  sed -i '' -E "s|^        - traefik\\.http\\.routers\\.grafana\\.rule=.*|        - traefik.http.routers.grafana.rule=Host(\`$GRAFANA_URL\`)|" "$COMPOSE_PATH"
else
  sed -i "s|{GRAFANA_ADMIN_PASSWORD}|$GRAFANA_ADMIN_PASSWORD|g" "$COMPOSE_PATH"
  sed -i "s|{grafana_url_here}|$GRAFANA_URL|g" "$COMPOSE_PATH"
  sed -i "s|^      - GF_SECURITY_ADMIN_PASSWORD=.*|      - GF_SECURITY_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD|" "$COMPOSE_PATH"
  sed -i -E "s|^        - traefik\\.http\\.routers\\.grafana\\.rule=.*|        - traefik.http.routers.grafana.rule=Host(\`$GRAFANA_URL\`)|" "$COMPOSE_PATH"
fi

# Verificar se as substituições foram feitas corretamente
echo "Verificando substituições..."
if grep -q "{" "$COMPOSE_PATH"; then
  echo "AVISO: Encontrados placeholders não substituídos:"
  grep -n "{" "$COMPOSE_PATH"
fi

# ============================
# Deploy da stack
# ============================
if [[ "$DEPLOY_CHOICE" == "s" ]]; then
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
  # Obter SwarmID de múltiplas formas
  # ============================
  if [[ "$STACK_MODE" == "swarm" ]]; then
    echo "Obtendo SwarmID..."
    
    # Verificar se SwarmID foi definido no arquivo de config
    if [[ -n "${SWARM_ID:-}" ]]; then
      echo "Usando SwarmID do arquivo de configuração: $SWARM_ID"
    else
      # Método 1: Tentar obter via API do Portainer diretamente
      echo "Tentativa 1: Obtendo SwarmID via API do Portainer..."
      SWARM_ID=$(curl -sk -H "Authorization: Bearer $JWT" "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/info" | jq -r '.Swarm.Cluster.ID // empty')
      echo "Resultado método 1: '$SWARM_ID'"
      
      # Método 2: Obter via comando docker info local
      if [[ -z "$SWARM_ID" || "$SWARM_ID" == "null" ]]; then
        echo "Tentativa 2: Obtendo SwarmID via comando docker info..."
        SWARM_ID=$(docker info --format '{{.Swarm.Cluster.ID}}' 2>/dev/null || echo "")
        echo "Resultado método 2: '$SWARM_ID'"
      fi
      
      # Método 3: Obter via inspect do swarm
      if [[ -z "$SWARM_ID" || "$SWARM_ID" == "null" ]]; then
        echo "Tentativa 3: Obtendo SwarmID via docker swarm inspect..."
        SWARM_ID=$(docker swarm inspect --format '{{ .ID }}' 2>/dev/null || echo "")
        echo "Resultado método 3: '$SWARM_ID'"
      fi
      
      # Método 4: Obter via node ls
      if [[ -z "$SWARM_ID" || "$SWARM_ID" == "null" ]]; then
        echo "Tentativa 4: Obtendo SwarmID via docker node ls..."
        SWARM_ID=$(docker node ls --format '{{ .ID }}' --filter "role=manager" | head -n1 2>/dev/null || echo "")
        echo "Resultado método 4: '$SWARM_ID'"
        
        # Se obtivemos um NodeID, precisamos converter para SwarmID
        if [[ -n "$SWARM_ID" ]]; then
          echo "Obtendo informações do node..."
          NODE_INFO=$(docker node inspect "$SWARM_ID" 2>/dev/null || echo "")
          if [[ -n "$NODE_INFO" ]]; then
            SWARM_ID=$(echo "$NODE_INFO" | jq -r '.[0].Spec.Labels."com.docker.swarm.service.name" // empty')
            echo "SwarmID extraído das informações do node: '$SWARM_ID'"
          fi
        fi
      fi
    fi
    
    # Verificar se conseguimos obter o SwarmID
    if [[ -z "$SWARM_ID" || "$SWARM_ID" == "null" ]]; then
      echo "ERRO: Não foi possível obter o SwarmID usando múltiplos métodos."
      echo "SwarmID atual: '$SWARM_ID'"
      echo ""
      echo "Diagnóstico:"
      echo "1. Verificando se o swarm está ativo:"
      docker info | grep -i "swarm:" || echo "   Comando falhou"
      echo ""
      echo "2. Verificando cluster ID:"
      docker info --format '{{.Swarm.Cluster.ID}}' || echo "   Comando falhou"
      echo ""
      echo "3. Obtendo informações via API do Portainer:"
      curl -sk -H "Authorization: Bearer $JWT" "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/info" | jq '.Swarm' || echo "   API falhou"
      echo ""
      echo "Soluções possíveis:"
      echo "1. Defina SWARM_ID manualmente no arquivo de configuração"
      echo "2. Verifique se o nó atual é um manager do swarm"
      echo "3. Execute: docker swarm init (se for um novo swarm)"
      exit 1
    fi
    
    echo "SwarmID final: $SWARM_ID"
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

  # Debug: mostrar payload se estiver em modo debug
  if [[ "$DEBUG_MODE" == "true" ]]; then
    echo "Payload que será enviado:"
    cat /tmp/stack_payload.json
  fi

  # Enviar o payload usando o arquivo temporário
  STACK_RESPONSE=$(curl -sk -w "%{http_code}" -o /tmp/portainer_stack.json \
    -X POST "$PORTAINER_URL/api/stacks/create/$STACK_MODE/string?endpointId=$ENDPOINT_ID" \
    -H "Authorization: Bearer $JWT" \
    -H "Content-Type: application/json" \
    -d @/tmp/stack_payload.json)

  if [[ "$STACK_RESPONSE" != "200" && "$STACK_RESPONSE" != "201" ]]; then
    echo "Erro ao criar stack (HTTP $STACK_RESPONSE)."
    echo "Payload enviado:"
    cat /tmp/stack_payload.json | jq .
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
    -d "{
      \"name\": \"Loki\",
      \"type\": \"loki\",
      \"access\": \"proxy\",
      \"url\": \"http://loki:3100\",
      \"basicAuth\": false,
      \"isDefault\": true
    }"
  echo "Datasource Loki criada com sucesso."
else
  echo -e "\n==== Copie o conteúdo abaixo e cole na interface do Portainer (Stacks) ===="
  cat "$COMPOSE_PATH"
  echo -e "\n==== Fim do docker-compose.yaml ===="
fi

echo "Deploy concluído! Logs podem ser encontrados em: $LOG_FILE"
