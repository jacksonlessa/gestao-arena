#!/usr/bin/env bash
# Quality gates — instalar como pre-commit hook nos repositórios de código:
#   cp .claude/hooks/pre-commit-check.sh front/.git/hooks/pre-commit
#   cp .claude/hooks/pre-commit-check.sh backend/.git/hooks/pre-commit
#   chmod +x front/.git/hooks/pre-commit backend/.git/hooks/pre-commit
#
# NÃO instalar no repositório de orquestração (a raiz). Ele só versiona
# `docs/`, `tasks/` e `.claude/` — rodar os gates de código num commit de
# markdown transforma qualquer quebra alheia em bloqueio de documentação, que
# foi exatamente o que aconteceu em 2026-09.
set -euo pipefail

echo "[pre-commit] Running EntreTimes quality gates..."

# Detecção de segredos primeiro: é o gate mais rápido e o de consequência
# mais cara se passar. O script vive na raiz do projeto, mas o hook roda de
# dentro de `front/` ou `backend/`, que são repositórios próprios — daí a
# resolução relativa em dois níveis.
SECRET_SCAN=""
for candidate in ".claude/hooks/scan-secrets.sh" "../.claude/hooks/scan-secrets.sh"; do
  [ -x "$candidate" ] && { SECRET_SCAN="$candidate"; break; }
done

if [ -n "$SECRET_SCAN" ]; then
  "$SECRET_SCAN"
else
  echo "[pre-commit] AVISO: scan-secrets.sh não encontrado — commit sem verificação de segredos." >&2
fi

# Qual repositório está commitando. O hook roda com o cwd na raiz do
# repositório em questão, então marcadores locais bastam — e é assim que os
# gates de um repositório param de ser cobrados no outro.
REPO=""
[ -f "nest-cli.json" ] && REPO="backend"
[ -f "next.config.ts" ] && REPO="front"

if [ -z "$REPO" ]; then
  echo "[pre-commit] Repositório sem gates de código (orquestração) — só a verificação de segredos."
  echo "[pre-commit] Quality gates passed."
  exit 0
fi

NPM_BIN=""
if [ -x "$HOME/.nvm/current/bin/node" ]; then
  NODE_VERSION="$("$HOME/.nvm/current/bin/node" -v)"
  CANDIDATE="$HOME/.nvm/versions/node/$NODE_VERSION/bin/npm"
  [ -x "$CANDIDATE" ] && NPM_BIN="$CANDIDATE"
fi

[ -z "$NPM_BIN" ] && NPM_BIN="$(command -v npm || true)"

# Prefer nvm npm over Windows-mounted npm on WSL
if [ -n "$NPM_BIN" ] && [[ "$NPM_BIN" == /mnt/c/* ]]; then
  if [ -x "$HOME/.nvm/current/bin/node" ]; then
    NODE_VERSION="$("$HOME/.nvm/current/bin/node" -v)"
    CANDIDATE="$HOME/.nvm/versions/node/$NODE_VERSION/bin/npm"
    [ -x "$CANDIDATE" ] && NPM_BIN="$CANDIDATE"
  fi
fi

if [ -z "$NPM_BIN" ]; then
  echo "[pre-commit] ERROR: npm not found (nvm not loaded?)." >&2
  exit 1
fi

echo "[pre-commit] Repositório: $REPO — usando npm: $NPM_BIN"

if [ "$REPO" = "backend" ]; then
  "$NPM_BIN" run lint
  "$NPM_BIN" run test
  # Paridade SQLite (dev) x MySQL (prod): produção aplica o schema via
  # `prisma db push`, sem histórico de migrations próprio, então uma
  # divergência aqui só apareceria no banco de produção.
  "$NPM_BIN" run check:schema-parity
else
  "$NPM_BIN" run lint
  "$NPM_BIN" run test
  # `next build` também é o gate de tipos do front.
  "$NPM_BIN" run build
fi

echo "[pre-commit] Quality gates passed."
