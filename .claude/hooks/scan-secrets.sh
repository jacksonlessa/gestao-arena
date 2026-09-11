#!/usr/bin/env bash
# Detecta segredos nas linhas ADICIONADAS pelo commit em andamento.
#
# Instalar junto do pre-commit (roda automaticamente via pre-commit-check.sh),
# ou rodar sozinho a qualquer momento:
#   .claude/hooks/scan-secrets.sh
#
# Funciona no repositório em que for executado — este projeto tem três
# (raiz, backend/, front/), cada um com seu próprio .git.
#
# Escopo deliberado: apenas o diff staged, não o histórico. Um segredo que já
# entrou no histórico não é impedido por hook nenhum — precisa ser revogado.
#
# Bypass consciente (use com parcimônia, e só para falso positivo):
#   SKIP_SECRET_SCAN=1 git commit ...
set -uo pipefail

[ "${SKIP_SECRET_SCAN:-0}" = "1" ] && { echo "[secrets] Ignorado via SKIP_SECRET_SCAN."; exit 0; }

FOUND=0

fail() {
  [ "$FOUND" -eq 0 ] && echo "" >&2
  FOUND=1
  echo "[secrets] $1" >&2
}

# --- 1. Arquivos de ambiente ---------------------------------------------
# `.env` nunca deve ser commitado; `.env.example` deve conter apenas
# placeholders. O .gitignore já cobre o caso normal, mas `git add -f` passa.
while IFS= read -r file; do
  case "$(basename "$file")" in
    .env.example|.env.sample|.env.template) ;;
    .env|.env.*)
      fail "arquivo de ambiente staged: $file"
      ;;
  esac
done < <(git diff --cached --name-only --diff-filter=ACM)

# --- 2. Padrões de credencial em linhas adicionadas ------------------------
# Só linhas com `+` (adicionadas), sem os cabeçalhos `+++`. Cada padrão é de
# alta confiança: formato próprio de um provedor, não heurística genérica.
ADDED="$(git diff --cached -U0 --diff-filter=ACM | grep -E '^\+' | grep -Ev '^\+\+\+' || true)"

check_pattern() {
  local label="$1" pattern="$2"
  local hits
  # `-e` explícito: padrões que começam com `-` (chave privada PEM) seriam
  # interpretados como opção do grep.
  hits="$(printf '%s\n' "$ADDED" | grep -nEo -e "$pattern" | head -3 || true)"
  if [ -n "$hits" ]; then
    fail "possível $label:"
    printf '%s\n' "$hits" | sed 's/^/           /' >&2
  fi
}

check_pattern "chave de API do SendGrid"        'SG\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{30,}'
check_pattern "access key da AWS"               'AKIA[0-9A-Z]{16}'
check_pattern "token do GitHub"                 'gh[pousr]_[A-Za-z0-9]{36,}'
check_pattern "token do Slack"                  'xox[baprs]-[A-Za-z0-9-]{10,}'
check_pattern "chave privada"                   '-----BEGIN [A-Z ]*PRIVATE KEY-----'
check_pattern "Auth Token da Twilio"            'SK[0-9a-fA-F]{32}'
check_pattern "URL de banco com senha"          '(mysql|postgres(ql)?)://[^:/@[:space:]]+:[^@[:space:]]{6,}@'

# --- 3. Atribuição de segredo com valor real ------------------------------
# Complementa os padrões acima para credenciais sem formato próprio (ex.:
# `R2_SECRET_ACCESS_KEY=c86...`). Três restrições evitam o falso positivo
# clássico — identificador de código como `inviteTokenService:
# InviteTokenService` ou `ACCESS_TOKEN_MAX_AGE_MS: DEFAULT_...`:
#
#   1. estilo env exige `CHAVE=valor` colado, sem espaço ao redor do `=`;
#   2. estilo código exige o valor entre aspas;
#   3. o valor precisa conter ao menos um dígito — segredo gerado tem
#      entropia, nome de variável não.
#
# O custo é não pegar um segredo composto só de letras; para os provedores
# que importam aqui, os padrões da seção 2 já cobrem esse caso.
QUOTE="[\"']"
ENV_ASSIGN="^\\+[A-Za-z0-9_]*(SECRET|TOKEN|PASSWORD|PASSWD|API_KEY|ACCESS_KEY|PRIVATE_KEY)[A-Za-z0-9_]*=${QUOTE}?[A-Za-z0-9+/=_-]{16,}"
CODE_ASSIGN="(secret|token|password|passwd|api_?key|access_?key|private_?key)[A-Za-z0-9_]*${QUOTE}?[[:space:]]*[:=][[:space:]]*${QUOTE}[A-Za-z0-9+/=_-]{16,}${QUOTE}"

ASSIGN_HITS="$(
  printf '%s\n' "$ADDED" \
    | grep -iEo -e "$ENV_ASSIGN" -e "$CODE_ASSIGN" \
    | grep -E '[0-9]' \
    | grep -Eiv '(\*{3,}|x{4,}|<[^>]+>|changeme|your[-_]|example|placeholder|dummy|fake|sample|test[-_]?secret)' \
    | head -3 || true
)"
if [ -n "$ASSIGN_HITS" ]; then
  fail "atribuição de segredo com valor aparentemente real:"
  printf '%s\n' "$ASSIGN_HITS" | sed 's/^/           /' >&2
fi

# --- Resultado -------------------------------------------------------------
if [ "$FOUND" -ne 0 ]; then
  cat >&2 <<'MSG'

[secrets] Commit bloqueado.

  Se for segredo real: NÃO basta remover do arquivo e commitar de novo —
  revogue a credencial no provedor. Ela é considerada comprometida a partir
  do momento em que existe fora do seu ambiente.

  Se for falso positivo: SKIP_SECRET_SCAN=1 git commit ...

MSG
  exit 1
fi

echo "[secrets] Nenhum segredo detectado nas linhas adicionadas."
