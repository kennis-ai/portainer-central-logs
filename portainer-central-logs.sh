#!/bin/bash

set -e

# Banner ASCII
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

# Solicita a senha do admin do Grafana e a URL desejada
read -rp "Informe a senha desejada para o admin do Grafana: " GRAFANA_ADMIN_PASSWORD
read -rp "Informe a URL desejada para o Grafana (ex: grafana.exemplo.com): " GRAFANA_URL

# Cria a rede Docker baseada no modo atual
if docker info | grep -q 'Swarm: active'; then
  NETWORK_DRIVER="overlay"
else
  NETWORK_DRIVER="bridge"
fi

echo "Criando rede Docker 'logging' com driver $NETWORK_DRIVER..."
docker network create --driver "$NETWORK_DRIVER" logging || echo "A rede 'logging' pode já existir."

# Cria volumes Docker
echo "Criando volumes Docker..."
for VOL in loki_data grafana_data loki_config promtail_config; do
  docker volume create "$VOL"
done

# Clona repositório
echo "Clonando repositório..."
rm -rf /tmp/portainer-central-logs
mkdir -p /tmp/portainer-central-logs
cd /tmp/portainer-central-logs

git clone https://github.com/kennis-ai/portainer-central-logs.git .

# Copia arquivos de configuração para os volumes
copy_to_volume() {
  VOL_NAME=$1
  FILE=$2
  DEST=$(docker volume inspect "$VOL_NAME" -f '{{ .Mountpoint }}')
  echo "Copiando $FILE para $DEST"
  cp "$FILE" "$DEST"
}

copy_to_volume loki_config local-config.yaml
copy_to_volume promtail_config config.yaml

# Substitui valores no docker-compose.yaml
sed -i "s|GF_SECURITY_ADMIN_PASSWORD=.*|GF_SECURITY_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD|" docker-compose.yaml
sed -i "s|Host\(`.*`\)|Host\(`$GRAFANA_URL`\)|" docker-compose.yaml

# Pergunta se deseja fazer o deploy automaticamente
read -rp "Deseja fazer o deploy automático da stack via API do Portainer? (s/n): " DEPLOY_CHOICE

if [[ "$DEPLOY_CHOICE" == "s" ]]; then
  read -rp "Informe o usuário admin do Portainer: " PORTAINER_USER
  read -rsp "Informe a senha do admin do Portainer: " PORTAINER_PASS && echo
  read -rp "Informe a URL do Portainer (ex: https://portainer.exemplo.com): " PORTAINER_URL
  read -rp "Informe o nome da stack [grafana]: " STACK_NAME
  STACK_NAME=${STACK_NAME:-grafana}

  # Login no Portainer
  echo "Realizando login no Portainer..."
  JWT=$(curl -sk -X POST "$PORTAINER_URL/api/auth" \
    -H "Content-Type: application/json" \
    -d "{\"Username\": \"$PORTAINER_USER\", \"Password\": \"$PORTAINER_PASS\"}" | jq -r .jwt)

  if [[ -z "$JWT" || "$JWT" == "null" ]]; then
    echo "Falha no login. Abortando."
    exit 1
  fi

  # Detecta edição do Portainer
  echo "Detectando edição do Portainer..."
  EDITION=$(curl -sk -H "Authorization: Bearer $JWT" "$PORTAINER_URL/api/status" | jq -r .Edition)
  echo "Edição detectada: $EDITION"

  # Obtém o ID do endpoint (assume apenas um local)
  ENDPOINT_ID=$(curl -sk -H "Authorization: Bearer $JWT" "$PORTAINER_URL/api/endpoints" | jq '.[0].Id')

  # Realiza o deploy da stack
  echo "Realizando deploy da stack $STACK_NAME..."
  curl -sk -X POST "$PORTAINER_URL/api/stacks" \
    -H "Authorization: Bearer $JWT" \
    -H "Content-Type: application/json" \
    -d "{
      \"Name\": \"$STACK_NAME\",
      \"EndpointId\": $ENDPOINT_ID,
      \"SwarmID\": \"\",
      \"StackFileContent\": \"$(sed 's/\\/\\\\/g' docker-compose.yaml | sed 's/"/\\"/g' | tr -d '\n')\",
      \"Env\": []
    }"

  echo "Aguardando os serviços da stack ficarem prontos..."
  until docker service ls | grep -q "$STACK_NAME"; do
    echo -n "."
    sleep 5
  done

  echo "\nStack implantada. Verificando serviços..."
  docker service ls | grep "$STACK_NAME"

  # Cria datasource Loki no Grafana
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

  echo "Datasource Loki criado com sucesso."

else
  echo "\n==== Copie o conteúdo abaixo e cole na interface do Portainer (Stacks) ===="
  cat docker-compose.yaml
  echo "\n==== Fim do conteúdo do docker-compose.yaml ===="
fi
