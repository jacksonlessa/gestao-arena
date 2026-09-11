#!/usr/bin/env bash
#
# Roda NO DROPLET, chamado pelo job `publicar` de
# .github/workflows/deploy-backend.yml.
#
# Publica um release que chega compilado do runner do GitHub Actions. Aqui não
# roda `npm ci` nem build: o droplet tem 1 GB de RAM compartilhado com outras
# aplicações, e compilar nele é o pico de memória do servidor.
#
# Copiado do EntreTimes e adaptado (D15: copiar, não compartilhar). Diferenças:
# `prisma migrate deploy` em vez de `db push` (schema único, RF06/RF14), sem
# uploads e sem migração de checkout antigo, e healthcheck que exige
# `status: "ok"` no JSON — o /health daqui responde 200 mesmo com o banco fora.
#
# Uso: remote-deploy.sh <release-id> <node-major-do-build>
#      O tarball precisa estar em "$BASE_DIR/incoming/<release-id>.tgz".
#
# Layout no droplet:
#   $BASE_DIR/releases/<id>/   um diretório por deploy (dist, node_modules, prisma)
#   $BASE_DIR/shared/.env      .env de produção — mantido à mão, fora do Git
#   $BASE_DIR/current          symlink para o release no ar
set -euo pipefail

RELEASE_ID="${1:?informe o release id}"
EXPECTED_NODE_MAJOR="${2:?informe a versão major do Node usada no build}"

APP_NAME="${APP_NAME:-gestao-arena-api}"
BASE_DIR="${BASE_DIR:-$HOME/apps/gestao-arena-api}"
KEEP_RELEASES="${KEEP_RELEASES:-3}"
HEALTH_PATH="${HEALTH_PATH:-/health}"
HEALTH_TIMEOUT_SECONDS="${HEALTH_TIMEOUT_SECONDS:-40}"
MAX_OLD_SPACE_MB="${MAX_OLD_SPACE_MB:-256}"

RELEASES_DIR="$BASE_DIR/releases"
SHARED_DIR="$BASE_DIR/shared"
INCOMING_DIR="$BASE_DIR/incoming"
RELEASE_DIR="$RELEASES_DIR/$RELEASE_ID"
TARBALL="$INCOMING_DIR/$RELEASE_ID.tgz"

# 1 = o release novo está (ou esteve) no ar e deve ser mantido em disco.
KEEP_NEW_RELEASE=0

log() { printf '[deploy] %s\n' "$*"; }
# `::error::` vira anotação no GitHub Actions — a saída do SSH é a do step.
fail() { printf '::error::%s\n' "$*"; exit 1; }

on_exit() {
  if [ "$KEEP_NEW_RELEASE" = 0 ] && [ -d "$RELEASE_DIR" ]; then
    rm -rf "$RELEASE_DIR"
  fi
  rm -f "$TARBALL"
}
trap on_exit EXIT

# Shell não interativo via SSH não lê o .bashrc: se Node/pm2 vierem do nvm,
# carrega aqui.
if [ -s "$HOME/.nvm/nvm.sh" ]; then
  # shellcheck disable=SC1091
  . "$HOME/.nvm/nvm.sh" >/dev/null
fi

# ---------------------------------------------------------------------------
# 1. Pré-checagens — nada em produção foi tocado ainda
# ---------------------------------------------------------------------------
for cmd in node pm2 tar; do
  command -v "$cmd" >/dev/null 2>&1 || fail "'$cmd' não está no PATH do usuário $(whoami) no droplet."
done

[ -f "$TARBALL" ] || fail "Tarball não encontrado: $TARBALL"

NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
if [ "$NODE_MAJOR" != "$EXPECTED_NODE_MAJOR" ]; then
  fail "O droplet roda Node $(node -v), mas o build foi feito com Node $EXPECTED_NODE_MAJOR. Ajuste NODE_VERSION em deploy-backend.yml ou atualize o Node do droplet."
fi

# O runner é Linux x86_64 com OpenSSL 3: node_modules e as engines do Prisma
# chegam compiladas para essa plataforma.
[ "$(uname -m)" = "x86_64" ] || fail "Arquitetura do droplet é $(uname -m); o build é para x86_64."
if command -v openssl >/dev/null 2>&1; then
  OPENSSL_MAJOR="$(openssl version | awk '{print $2}' | cut -d. -f1)"
  [ "$OPENSSL_MAJOR" = "3" ] || fail "Droplet com OpenSSL $OPENSSL_MAJOR.x; as engines do Prisma vêm do runner com OpenSSL 3."
fi

mkdir -p "$RELEASES_DIR" "$SHARED_DIR"
[ -f "$SHARED_DIR/.env" ] || fail "Não existe $SHARED_DIR/.env. Crie o .env de produção nesse caminho (.github/deploy/README.md, passo 3)."

# ---------------------------------------------------------------------------
# 2. Descompacta o release
# ---------------------------------------------------------------------------
[ ! -e "$RELEASE_DIR" ] || fail "Release $RELEASE_ID já existe em $RELEASES_DIR."
log "Descompactando release $RELEASE_ID"
mkdir -p "$RELEASE_DIR"
tar -xzf "$TARBALL" -C "$RELEASE_DIR"
rm -f "$TARBALL"
ln -sfn "$SHARED_DIR/.env" "$RELEASE_DIR/.env"

# ---------------------------------------------------------------------------
# 3. Migrações (RF14: modo produção, nunca `migrate dev`)
# ---------------------------------------------------------------------------
# Roda ANTES da troca de versão, com a versão anterior ainda no ar. Por isso a
# migração precisa ser compatível com o código anterior — mudança destrutiva
# vai em duas etapas: expandir, migrar dados, contrair (PRD 00).
log "Aplicando migrações (prisma migrate deploy)"
if ! (cd "$RELEASE_DIR" && ./.deploy-tools/prisma/node_modules/.bin/prisma migrate deploy \
      --schema=prisma/schema.prisma); then
  fail "prisma migrate deploy falhou. Nenhuma versão nova foi publicada. Confira o log acima; se uma migração ficou pela metade, veja 'Migração que falhou' em .github/deploy/README.md."
fi

# ---------------------------------------------------------------------------
# 4. Troca de versão, healthcheck e rollback
# ---------------------------------------------------------------------------
PORT="$(grep -E '^[[:space:]]*PORT[[:space:]]*=' "$SHARED_DIR/.env" | tail -n 1 | cut -d= -f2- | tr -d " \"'\r" || true)"
[ -n "$PORT" ] || fail "Defina PORT em $SHARED_DIR/.env."
HEALTH_URL="http://127.0.0.1:${PORT}${HEALTH_PATH}"

PREV_DIR=""
if [ -L "$BASE_DIR/current" ] && [ -f "$BASE_DIR/current/dist/main.js" ]; then
  PREV_DIR="$(readlink -f "$BASE_DIR/current")"
fi

port_in_use() {
  node -e '
    const s = require("net").connect(Number(process.argv[1]), "127.0.0.1");
    s.on("connect", () => { s.destroy(); process.exit(0); });
    s.on("error", () => process.exit(1));
  ' "$PORT"
}

# Saudável = HTTP 2xx E `status: "ok"` no corpo. Este /health responde 200
# também quando o banco está fora (status "degradado"), então só o código HTTP
# deixaria passar uma versão sem banco.
healthy() {
  node -e '
    fetch(process.argv[1], { signal: AbortSignal.timeout(3000) })
      .then(async (r) => {
        if (!r.ok) process.exit(1);
        const body = await r.json().catch(() => ({}));
        process.exit(body.status === "ok" ? 0 : 1);
      })
      .catch(() => process.exit(1));
  ' "$HEALTH_URL"
}

wait_healthy() {
  local deadline=$((SECONDS + HEALTH_TIMEOUT_SECONDS))
  until healthy; do
    [ "$SECONDS" -lt "$deadline" ] || return 1
    sleep 2
  done
  # Segunda checagem: pega o processo que sobe e cai logo em seguida.
  sleep 5
  healthy
}

# Sobe `dir` sob o nome $APP_NAME, derrubando o que estiver com esse nome.
# O `--cwd` aponta para o diretório real do release (não para `current`),
# então um restart do pm2 nunca troca de versão por baixo dos panos.
start_app() {
  local dir="$1"
  pm2 delete "$APP_NAME" >/dev/null 2>&1 || true

  local waited=0
  while port_in_use; do
    if [ "$waited" -ge 10 ]; then
      return 2
    fi
    sleep 1
    waited=$((waited + 1))
  done

  pm2 start "$dir/dist/main.js" \
    --name "$APP_NAME" \
    --cwd "$dir" \
    --node-args="--max-old-space-size=${MAX_OLD_SPACE_MB}" >/dev/null
}

rollback() {
  local reason="$1"
  log "Últimas linhas de log do processo:"
  pm2 logs "$APP_NAME" --lines 60 --nostream 2>&1 || true

  KEEP_NEW_RELEASE=0
  if [ -z "$PREV_DIR" ]; then
    pm2 delete "$APP_NAME" >/dev/null 2>&1 || true
    rm -f "$BASE_DIR/current"
    fail "$reason Primeiro deploy: não há versão anterior para restaurar."
  fi

  log "Restaurando versão anterior: $PREV_DIR"
  ln -sfn "$PREV_DIR" "$BASE_DIR/current"
  if start_app "$PREV_DIR" && wait_healthy; then
    pm2 save >/dev/null
    fail "$reason Versão anterior restaurada e respondendo."
  fi
  fail "$reason O rollback TAMBÉM falhou — a API está FORA DO AR. Verifique 'pm2 logs $APP_NAME' no droplet."
}

log "Publicando $RELEASE_ID (anterior: ${PREV_DIR:-nenhuma})"
KEEP_NEW_RELEASE=1
ln -sfn "$RELEASE_DIR" "$BASE_DIR/current"

set +e
start_app "$RELEASE_DIR"
start_status=$?
set -e
if [ "$start_status" = 2 ]; then
  rollback "A porta $PORT continuou ocupada depois de parar '$APP_NAME' — outro processo está usando essa porta."
elif [ "$start_status" != 0 ]; then
  rollback "pm2 não conseguiu iniciar a nova versão."
fi

if ! wait_healthy; then
  rollback "A nova versão não respondeu status \"ok\" em $HEALTH_URL dentro de ${HEALTH_TIMEOUT_SECONDS}s."
fi

pm2 save >/dev/null
log "Release $RELEASE_ID no ar e saudável em $HEALTH_URL"

# ---------------------------------------------------------------------------
# 5. Limpeza: mantém os $KEEP_RELEASES releases mais recentes
# ---------------------------------------------------------------------------
CURRENT_REAL="$(readlink -f "$BASE_DIR/current")"
find "$RELEASES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
  | sort \
  | head -n -"$KEEP_RELEASES" \
  | while read -r old; do
      [ "$RELEASES_DIR/$old" = "$CURRENT_REAL" ] && continue
      log "Removendo release antigo $old"
      rm -rf "${RELEASES_DIR:?}/$old"
    done
