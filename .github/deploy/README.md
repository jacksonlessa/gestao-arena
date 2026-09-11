# Deploy do backend

`deploy-backend.yml` publica o backend no droplet da DigitalOcean a cada push
na `main` que altere `backend/**`, os workflows do backend ou esta pasta
(RF26). Também dá para disparar à mão, em *Actions → Deploy backend → Run
workflow*.

Mesmo modelo do EntreTimes: **o build acontece inteiro no runner do GitHub**. O
droplet (1 GB de RAM, dividido com EntreTimes, Latemia e o MySQL) só recebe o
resultado pronto.

## Fluxo

```
push main ──► qualidade (backend-ci.yml: MySQL 8.0 de serviço,
              │          migrate deploy num banco vazio, lint, teste, build)
              │ verde (RF27)
              ▼
            publicar (runner ubuntu-24.04)
              npm ci → prisma generate → nest build
              CLI do Prisma em .deploy-tools/ → npm prune --omit=dev
              tar.gz: dist, node_modules, prisma, package*.json, REVISION
              │ scp
              ▼
            droplet: .github/deploy/remote-deploy.sh
              pré-checagens (Node, x86_64, OpenSSL 3, shared/.env)
              prisma migrate deploy (RF14) → troca a versão no pm2
              /health local com status "ok" → pm2 save + limpeza
                                            falha: volta para a versão anterior
              │
              ▼
            /health público (DNS + Nginx + TLS)
```

- **Um deploy por vez** (`concurrency: deploy-backend`).
- O `/health` responde 200 mesmo com o banco fora (`status: "degradado"`). Por
  isso o deploy exige `status: "ok"` no corpo, não só o código HTTP.
- **Troca de versão:** `pm2 delete` + `pm2 start`, com alguns segundos de 502.
  Aceitável agora; rever quando houver arena usando a agenda em horário de
  pico.
- Cada processo sobe com `--max-old-space-size=256`.
- **Migração antes da troca:** o `migrate deploy` roda com a versão anterior
  ainda no ar, e um rollback de código **não desfaz** a migração. Mudança
  destrutiva segue em duas etapas: expandir, migrar dados, contrair (PRD 00).

## Layout no droplet

Roda sob o usuário `entretimes-deploy`, no mesmo pm2 do EntreTimes: não cria
mais um daemon e reaproveita o acesso SSH.

```
/home/entretimes-deploy/apps/gestao-arena-api/
├── current -> releases/<id>
├── releases/<id>/               # 3 últimos (KEEP_RELEASES)
│   ├── dist/ node_modules/ prisma/ .deploy-tools/ REVISION
│   └── .env -> ../../shared/.env
├── shared/.env                  # .env de produção, mantido à mão
└── incoming/                    # tarball em trânsito
```

Processo no pm2: `gestao-arena-api`. Porta: `3004` (definida no `shared/.env`).

## Configuração única do droplet

Faça uma vez, na ordem. Os passos 1, 2 e 4 são como `root`; o 3 como
`entretimes-deploy`.

### 1. Porta livre

```bash
ss -ltnp | grep -w 3004 || echo "3004 livre"
```

Se estiver ocupada, escolha outra e use-a nos passos 3 e 4.

### 2. Banco e usuário no MySQL

O MySQL é compartilhado: usuário próprio, com acesso só a este banco.

```bash
SENHA=$(openssl rand -base64 24 | tr -d '/+=')   # só letras e números: vai numa URL
echo "$SENHA"                                     # guarde para o passo 3

mysql <<SQL
CREATE DATABASE gestao_arena CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER 'gestao_arena'@'localhost' IDENTIFIED BY '$SENHA';
GRANT ALL PRIVILEGES ON gestao_arena.* TO 'gestao_arena'@'localhost';
SQL
```

### 3. `.env` de produção

```bash
sudo -iu entretimes-deploy
mkdir -p ~/apps/gestao-arena-api/shared
cat > ~/apps/gestao-arena-api/shared/.env <<'ENV'
NODE_ENV=production
PORT=3004
# connection_limit é obrigatório: o MySQL é dividido com outras aplicações.
DATABASE_URL="mysql://gestao_arena:SENHA_DO_PASSO_2@localhost:3306/gestao_arena?connection_limit=5"
CORS_ORIGIN_OPERACAO="https://arenas.entretimes.com.br"
CORS_ORIGIN_BACKOFFICE="https://backoffice-arenas.entretimes.com.br"
APP_NAME="gestao-arena-api"
APP_VERSION="0.1.0"
ENV
chmod 600 ~/apps/gestao-arena-api/shared/.env
```

Trocar `SENHA_DO_PASSO_2`. Depois de editar o `.env` com a aplicação já no ar:
`pm2 restart gestao-arena-api`.

### 4. DNS, Nginx e TLS

1. **DNS:** registro `A` de `arenas-api.entretimes.com.br` apontando para o IP
   do droplet, no mesmo lugar do `api.entretimes.com.br`.
2. **Nginx:** copie o vhost do EntreTimes e troque domínio e porta:

   ```bash
   ls /etc/nginx/sites-enabled/          # achar o do api.entretimes.com.br
   cp /etc/nginx/sites-available/<vhost-do-entretimes> \
      /etc/nginx/sites-available/arenas-api.entretimes.com.br
   # editar: server_name arenas-api.entretimes.com.br;
   #         proxy_pass http://127.0.0.1:3004;
   #         remover as linhas ssl_* / listen 443 copiadas (o certbot recria)
   ln -s /etc/nginx/sites-available/arenas-api.entretimes.com.br /etc/nginx/sites-enabled/
   nginx -t && systemctl reload nginx
   ```

3. **TLS:** faça igual ao EntreTimes. Se o vhost dele tem
   `ssl_certificate /etc/letsencrypt/...`, rode
   `certbot --nginx -d arenas-api.entretimes.com.br`. Se o DNS passa pelo proxy
   da Cloudflare, repita a configuração de lá.

> **Para o PRD 01:** atrás do Nginx, toda requisição chega de `127.0.0.1`. Sem
> `app.set('trust proxy', 1)` no `main.ts`, o throttle de login (5/min) passa a
> valer para **todos os usuários juntos**, não por IP.

## Secrets do repositório

Settings → Secrets and variables → Actions:

| Secret | Valor |
|---|---|
| `DEPLOY_HOST` | IP do droplet (o mesmo do EntreTimes) |
| `DEPLOY_USER` | `entretimes-deploy` |
| `DEPLOY_SSH_KEY` | chave privada **própria deste repositório** (abaixo) |
| `DEPLOY_KNOWN_HOSTS` | as mesmas linhas cadastradas no EntreTimes |
| `DEPLOY_PORT` | só se o SSH não for na porta 22 |

Chave própria, e não a do EntreTimes: dá para revogar uma sem derrubar o
deploy da outra. No seu Mac:

```bash
ssh-keygen -t ed25519 -N "" -C "gestao-arena-deploy" -f ~/.ssh/gestao_arena_deploy
cat ~/.ssh/gestao_arena_deploy.pub   # → acrescentar ao authorized_keys (abaixo)
cat ~/.ssh/gestao_arena_deploy       # → colar no secret DEPLOY_SSH_KEY
```

No droplet, como root:

```bash
echo '<conteúdo do .pub>' >> /home/entretimes-deploy/.ssh/authorized_keys
```

Teste do Mac: `ssh -i ~/.ssh/gestao_arena_deploy entretimes-deploy@<IP> 'node -v'`
precisa responder `v24.x`.

`DEPLOY_KNOWN_HOSTS`, gerado no droplet:

```bash
HOST=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)
for f in /etc/ssh/ssh_host_{ed25519,ecdsa,rsa}_key.pub; do
  [ -f "$f" ] && echo "$HOST $(cut -d' ' -f1,2 "$f")"
done
```

Os secrets antigos `DO_HOST`, `DO_USER`, `DO_SSH_KEY` e `DO_APP_PATH`, se
existirem, podem ser apagados.

## Primeiro deploy

*Actions → Deploy backend → Run workflow*. O log do passo *Activate release*
termina com `Release … no ar e saudável`, e o *Public healthcheck* com
`Healthcheck público ok`. Os três healthchecks do README (operação, backoffice
e API) fecham o critério de aceite do PRD 00.

## Operação

### Migração que falhou

Se o `migrate deploy` parar no meio, o Prisma marca a migração como falha
(`P3009`) e **todo deploy seguinte é recusado** até resolver. Nada foi
publicado; a versão anterior segue no ar. Depois de corrigir o banco à mão:

```bash
cd ~/apps/gestao-arena-api/current
./.deploy-tools/prisma/node_modules/.bin/prisma migrate resolve \
  --rolled-back <nome_da_migracao> --schema=prisma/schema.prisma
```

E rode o workflow de novo.

### Rollback manual

Refazer o deploy de um commit anterior: *Re-run jobs* na execução daquele
commit. Ou, no droplet, voltar para um release em disco:

```bash
cd ~/apps/gestao-arena-api && ls releases
R=releases/<id>
pm2 delete gestao-arena-api
pm2 start "$PWD/$R/dist/main.js" --name gestao-arena-api --cwd "$PWD/$R" \
  --node-args="--max-old-space-size=256"
ln -sfn "$PWD/$R" current && pm2 save
```

Lembrando: o schema do banco não volta junto.
