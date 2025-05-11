# Portainer Central Logs

Este guia foi criado para ajudar pessoas com pouca ou nenhuma experiência técnica a instalar e configurar automaticamente um sistema de monitoramento centralizado com Grafana, Loki e Promtail, utilizando Docker e Portainer.

## O que este script faz?

O script `portainer-central-logs.sh` realiza automaticamente todas estas etapas para você:

1. **Prepara o ambiente**: Cria uma rede Docker e volumes para armazenar dados
2. **Baixa as configurações**: Obtém arquivos necessários do GitHub
3. **Personaliza sua instalação**: Aplica suas senhas e URLs personalizadas
4. **Instala automaticamente**: Conecta com seu Portainer e instala todo o sistema
5. **Espera tudo ficar pronto**: Aguarda todos os serviços iniciarem corretamente
6. **Configura o Grafana**: Cria automaticamente a conexão com o Loki
7. **Mostra o resultado**: Informa onde e como acessar seu sistema

## Pré-requisitos

Você vai precisar apenas destes itens em seu servidor:

- ✅ Docker instalado (o Portainer cuida do resto)
- ✅ Portainer funcionando (Community ou Business Edition)
- ✅ Acesso ao terminal com permissões de administrador
- ✅ Conexão com a internet

**Não sabe se tem Docker e Git?** Execute no terminal:
```bash
docker --version
git --version
```

**Se aparecer algo como "command not found"**, peça ajuda para instalar estes programas.

## Passo a passo simples

### 1. Baixe o script

No terminal do seu servidor, cole este comando:
```bash
curl -o portainer-central-logs.sh https://raw.githubusercontent.com/kennis-ai/portainer-central-logs/main/portainer-central-logs.sh
```

### 2. Dê permissão para executar

```bash
chmod +x portainer-central-logs.sh
```

### 3. Execute o script

#### Opção 1: Execução básica (responde perguntas)
```bash
./portainer-central-logs.sh
```

#### Opção 2: Usando arquivo de configuração (mais rápido)
Se você vai instalar várias vezes ou quer evitar digitar as informações toda vez:

```bash
./portainer-central-logs.sh --config=portainer-config.conf
```

Para usar esta opção, primeiro crie um arquivo chamado `portainer-config.conf` com este conteúdo:
```
GRAFANA_ADMIN_PASSWORD="sua_senha_aqui"
GRAFANA_URL="grafana.suaempresa.com"
DEPLOY_CHOICE="s"
PORTAINER_USER="admin"
PORTAINER_PASS="senha_do_portainer"
PORTAINER_URL="https://portainer.suaempresa.com"
STACK_NAME="grafana"
```

#### Opção 3: Modo debug (se algo der errado)
```bash
./portainer-central-logs.sh --config=portainer-config.conf debug
```

## O que o script vai perguntar

Se você não usar arquivo de configuração, o script vai fazer estas perguntas:

1. **"Informe a senha desejada para o admin do Grafana"**
   - Digite uma senha forte que você vai usar para acessar o Grafana

2. **"Informe a URL desejada para o Grafana"**
   - Digite apenas o domínio, por exemplo: `grafana.minhaempresa.com`
   - NÃO coloque `https://` na frente

3. **"Deseja fazer o deploy automático via API do Portainer?"**
   - Digite `s` para sim (recomendado) ou `n` para não

Se você escolher `s` (sim), ele vai perguntar:

4. **"Usuário admin do Portainer"**
   - Normalmente é `admin`

5. **"Senha do Portainer"**
   - A senha que você usa para entrar no Portainer

6. **"URL do Portainer"**
   - Por exemplo: `https://portainer.minhaempresa.com`

7. **"Nome da stack [grafana]"**
   - Aperte ENTER para usar `grafana` ou digite outro nome

## Aguarde o processo

Depois de responder as perguntas, **não feche o terminal**. O script vai:

- Baixar arquivos necessários
- Aplicar suas configurações
- Conectar no Portainer
- Criar todos os serviços
- Esperar tudo ficar pronto (isso pode levar alguns minutos)
- Configurar o Grafana automaticamente

Você verá mensagens como:
```
Aguardando grafana....... PRONTO (45s)
Aguardando loki.......... PRONTO (30s)
Aguardando promtail...... PRONTO (15s)
```

## Após a instalação

1. **Acesse o Grafana**
   - Abra seu navegador
   - Vá para a URL que você configurou (ex: `https://grafana.suaempresa.com`)
   
2. **Faça login**
   - Usuário: `admin`
   - Senha: a que você definiu no script

3. **Está pronto!**
   - O Loki já está configurado como fonte de dados
   - Seus logs já estão sendo coletados
   - Você pode começar a criar dashboards

## Se algo der errado

1. **Execute com modo debug**:
   ```bash
   ./portainer-central-logs.sh debug
   ```

2. **Verifique o arquivo de log**:
   ```bash
   cat portainer-deploy.log
   ```

3. **Mensagens de erro comuns**:
   - "Command not found": Instale o programa mencionado
   - "Permission denied": Use `sudo` antes do comando
   - "Cannot connect": Verifique se as URLs estão corretas

## Suporte

Se precisar de ajuda:

- Procure o arquivo `portainer-deploy.log` para ver detalhes do erro
- Entre em contato com o suporte da Kennis
- Consulte a documentação oficial do Portainer e Grafana

---

Este projeto é mantido por [Kennis](https://kennis.com.br), especializada em soluções de observabilidade, dados e automação inteligente.
