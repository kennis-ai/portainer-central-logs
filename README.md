# Portainer Central Logs

Este guia foi criado para ajudar pessoas com pouca ou nenhuma experiência técnica a instalar e configurar automaticamente um sistema de monitoramento centralizado com Grafana, Loki e Promtail, utilizando Docker e Portainer.

## O que este script faz?

O script `portainer-central-logs.sh` realiza automaticamente as seguintes etapas:

1. Cria uma rede Docker chamada `logging`, compatível com o modo atual do Docker (Swarm ou Standalone).
2. Cria volumes Docker para persistência de dados do Loki, Grafana e arquivos de configuração.
3. Faz o download de arquivos de configuração do repositório oficial da Kennis no GitHub.
4. Solicita a senha de administrador e a URL desejada para acessar o Grafana.
5. Atualiza automaticamente o arquivo `docker-compose.yaml` com as informações fornecidas.
6. Pergunta se você deseja implantar a stack automaticamente usando a API do Portainer ou copiar o conteúdo manualmente.
7. Se for automática, realiza o login no Portainer e faz o deploy completo.
8. Aguarda a inicialização dos serviços.
9. Cria a conexão com a fonte de dados Loki dentro do Grafana automaticamente.

## Pré-requisitos

Antes de rodar o script, você precisa:

* Um servidor Linux com Docker já instalado.
* Portainer Community ou Business Edition já configurado e acessível.
* Git instalado (para clonar os arquivos do GitHub).
* Acesso ao terminal com permissões administrativas (root ou sudo).

## Passo a passo para usar o script

### 1. Fazer o download do script

Abra o terminal do seu servidor e execute:

```bash
curl -o portainer-central-logs.sh https://raw.githubusercontent.com/kennis-ai/portainer-central-logs/main/portainer-central-logs.sh
```

### 2. Dar permissão de execução ao script

```bash
chmod +x portainer-central-logs.sh
```

### 3. Executar o script

```bash
./portainer-central-logs.sh
```

O script começará a rodar e irá pedir as seguintes informações:

* **Senha desejada do admin do Grafana** – Essa senha será usada para acessar a interface do Grafana.
* **URL desejada para acessar o Grafana** – Por exemplo: `grafana.suaempresa.com.br`.
* **Se deseja fazer o deploy automático via Portainer** – Responda com "s" para sim ou "n" para não.

  * Se você responder "s", ele pedirá:

    * Usuário admin do Portainer
    * Senha admin do Portainer
    * URL do Portainer (ex: [https://portainer.suaempresa.com.br](https://portainer.suaempresa.com.br))
    * Nome da stack (padrão: grafana)

Se optar por fazer o deploy manual, o script irá imprimir o conteúdo do `docker-compose.yaml` para que você copie e cole na interface do Portainer.

## Após a instalação

* Acesse o Grafana pela URL informada.
* Faça login com o usuário `admin` e a senha que você definiu.
* A fonte de dados Loki já estará configurada como padrão.

## Suporte

Se você encontrar problemas durante a execução do script, entre em contato com o suporte da Kennis ou consulte a documentação oficial do Portainer e Grafana.

---

Este projeto é mantido por [Kennis](https://kennis.com.br), especializada em soluções de observabilidade, dados e automação inteligente.
