# PRD — Setup do Ambiente

## Visão Geral

Estabelecer o esqueleto do monorepo do Gestão de Arena: backend, frontend, banco
local, pipeline de qualidade e publicação. Nenhuma regra de negócio entra aqui.

O produto tem duas aplicações servidas em hosts distintos a partir do mesmo
frontend — a operação da arena e o backoffice do provedor. Essa separação precisa
existir desde o primeiro commit, porque retrofitar isolamento de sessão depois
custa mais do que criá-lo agora.

## Objetivos

- `git clone` seguido de um comando sobe o ambiente completo em uma máquina limpa.
- Os dois hosts do frontend respondem, cada um servindo sua própria aplicação, e
  nenhum deles serve o conteúdo do outro.
- Cada superfície tem healthcheck próprio, permitindo verificar local e produção da
  mesma forma.
- Alteração restrita a um dos lados publica apenas aquele lado.
- Lint, testes e build rodam em CI e barram publicação com falha.

**Métricas de sucesso**

1. Tempo entre clonar o repositório e ter o ambiente rodando: menos de 10 minutos.
2. Commit que toca apenas `docs/` não dispara nenhuma publicação.
3. Os três healthchecks — operação, backoffice e backend — respondendo tanto no
   ambiente local quanto em produção, após a primeira publicação.

## Histórias de Usuário

- Como desenvolvedor, quero subir todo o ambiente com um comando, para não perder
  tempo com configuração a cada máquina nova.
- Como desenvolvedor, quero que o banco local seja igual ao de produção, para não
  descobrir diferença de tipo só na publicação.
- Como desenvolvedor, quero que um commit em documentação não reinicie o backend,
  para não causar indisponibilidade sem motivo.
- Como desenvolvedor, quero que teste vermelho impeça a publicação, para não
  publicar quebrado sem perceber.

## Funcionalidades Principais

### 1. Estrutura do repositório

- **RF01** — Repositório único contendo `front/`, `backend/`, `docs/`, `ia-docs/`,
  `tasks/` e `.claude/`, versionados juntos.
- **RF02** — `ia-docs/` e `.claude/` são adaptados do EntreTimes, preservando o
  pipeline `/create-prd` → `/create-techspec` → `/create-tasks` → `/run-next-task`.
- **RF03** — `CLAUDE.md` na raiz descreve stack, arquitetura, convenções e scripts.
- **RF04** — `.gitignore` cobre `node_modules`, `.env`, artefatos de build e dados
  do banco local.

### 2. Backend

- **RF05** — Aplicação NestJS com estrutura modular por domínio: controller fino,
  service com a regra, module para wiring, DTOs com validação de entrada.
- **RF06** — Prisma como acesso a dados, com **um único schema** para
  desenvolvimento e produção.
- **RF07** — Acesso ao Prisma exclusivamente por um serviço dedicado; o client não é
  instanciado fora dele.
- **RF08** — Endpoint de healthcheck público no backend, informando situação da
  aplicação e conectividade com o banco.
- **RF09** — Validação de variáveis de ambiente obrigatórias na inicialização em
  produção, falhando rápido quando faltar alguma.
- **RF10** — CORS restrito a uma lista explícita de origens, vinda de variável de
  ambiente, com credenciais habilitadas. Nunca curinga — e nunca curinga junto com
  credenciais, combinação que o navegador recusa.
- **RF10a** — As origens permitidas são declaradas por superfície: host da operação
  e host do backoffice. Rotas do backoffice validam a origem no servidor e recusam
  chamada vinda do host da operação, mesmo que o cookie seja válido.
- **RF11** — Valores monetários usam tipo decimal exato; datas usam tipo sem
  conversão implícita de fuso, armazenadas em UTC.

### 3. Banco de dados local

- **RF12** — `docker-compose.yml` sobe MySQL na mesma versão principal da produção,
  com volume nomeado para persistir entre reinícios.
- **RF13** — Script único que sobe o banco, aplica as migrações e executa o seed.
- **RF14** — O pipeline de publicação aplica migrações em modo produção, nunca em
  modo de desenvolvimento.

### 4. Frontend e separação por host

- **RF15** — Aplicação Next.js com App Router e Tailwind.
- **RF16** — As rotas ficam sob dois prefixos físicos: um para a operação e um para
  o backoffice, cada um com seu próprio layout.
- **RF17** — Um middleware reescreve a requisição para o prefixo correspondente ao
  host, sem que o prefixo apareça na URL vista pelo usuário.
- **RF18** — O middleware **responde 404** quando a URL pedida corresponde ao
  prefixo do outro host. Sem isso, a separação não existe de fato.
- **RF19** — O frontend chama o backend diretamente no domínio da API, com
  credenciais. Como os três domínios compartilham o mesmo domínio registrável, as
  requisições são **same-site**: os cookies usam `SameSite=Lax` e mantêm a proteção
  contra CSRF entre sites, sem precisar de `SameSite=None`.
- **RF20** — Cada host do frontend expõe sua própria rota de healthcheck,
  identificando qual aplicação respondeu. Somando o backend, são **três
  verificações independentes** — operação, backoffice e backend — e elas são o
  critério de aceite de RF17 e RF18, tanto no ambiente local quanto em produção.
- **RF20a** — O healthcheck de cada host do frontend **chama o healthcheck do
  backend a partir do navegador**, com credenciais, e exibe o resultado ao lado do
  seu próprio. É essa chamada que prova, em uma tela só, que CORS, conectividade e
  configuração de cookie estão corretos — tanto no ambiente local quanto em
  produção.
- **RF20b** — Cada host serve uma página mínima, sem autenticação, confirmando
  visualmente qual aplicação está sendo servida.

### 5. Qualidade e publicação

- **RF21** — Scripts de lint, teste e build disponíveis nos dois lados.
- **RF22** — Formatação e configuração de TypeScript equivalentes entre `front/` e
  `backend/`, herdadas do EntreTimes.
- **RF23** — Testes nomeados no padrão `should <comportamento> when <condição>`.
- **RF24** — CI executa lint, teste e build a cada push na branch principal.
- **RF25** — Publicação do frontend na Vercel, apenas quando houver alteração em
  `front/`.
- **RF26** — Publicação do backend por GitHub Actions para DigitalOcean, apenas
  quando houver alteração em `backend/` ou no próprio workflow.
- **RF27** — Falha de lint, teste ou build impede a publicação.
- **RF28** — Segredos apenas por variáveis de ambiente e GitHub Actions Secrets,
  nunca versionados. `.env.example` comentado linha a linha nos dois lados.

## Experiência do Usuário

O único usuário deste PRD é o desenvolvedor. O fluxo esperado é: clonar, copiar os
`.env.example`, rodar o script de ambiente, abrir os dois hosts locais e ver cada
aplicação responder na sua página mínima.

Em desenvolvimento, os dois hosts são distinguidos por entradas locais de host ou
por portas distintas, replicando o comportamento de produção sem exigir domínio
real.

## Restrições Técnicas de Alto Nível

- Backend NestJS com Prisma; frontend Next.js com App Router; MySQL nos dois
  ambientes.
- Frontend publicado na Vercel; backend em DigitalOcean via GitHub Actions.
- Domínios de produção:

  | Superfície | Domínio |
  |---|---|
  | Operação (frontend) | `arenas.entretimes.com.br` |
  | Backoffice (frontend) | `backoffice-arenas.entretimes.com.br` |
  | API (backend) | `arenas-api.entretimes.com.br` |

- Os três compartilham o domínio registrável `entretimes.com.br` e são, portanto,
  **same-site** entre si — o que permite `SameSite=Lax` nos cookies. Isso **não**
  vale para URLs de preview em `*.vercel.app`, que são cross-site.
- Um único projeto Vercel atende os dois domínios de frontend.
- Trabalho direto na branch principal enquanto não houver arena real em produção.
- Migração destrutiva de schema é feita em duas etapas — expandir, migrar dados,
  contrair — porque a publicação automática não oferece janela de revisão.

## Não-Objetivos (Fora de Escopo)

- Qualquer regra de negócio, entidade de domínio ou tela funcional.
- Autenticação, que é assunto do PRD seguinte.
- Ambiente de homologação separado.
- Fluxo de branch e pull request.
- Observabilidade além do healthcheck.
- Backup automatizado do banco de produção.

## Questões em Aberto

Resolvidas no esqueleto, registradas aqui por rastreabilidade:

- **MySQL 8.0** fixado em desenvolvimento, acompanhando o servidor de produção,
  que roda o 8.0 empacotado pelo Ubuntu 24.04.
- **Hosts em desenvolvimento**: `arenas.localhost` e `backoffice-arenas.localhost`,
  que resolvem para 127.0.0.1 sozinhos nos navegadores atuais, sem `/etc/hosts`.
  O banco local expõe a porta **3307** para não colidir com um MySQL já instalado.
- **Execução no droplet**: `pm2` sob o usuário `entretimes-deploy` (o mesmo do
  EntreTimes), com releases compilados no runner e trocados com healthcheck e
  rollback. Detalhes em `.github/deploy/README.md`.

Ainda em aberto:

1. Como autenticar em deploys de preview da Vercel, que ficam em `*.vercel.app` e
   são cross-site: apontar previews para subdomínio de `entretimes.com.br`, ou
   deixar previews sem sessão autenticada.
2. Se `arenas-api` fica atrás de proxy com TLS gerenciado no droplet ou de um
   balanceador.
