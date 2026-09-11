#!/usr/bin/env bash
# PostToolUse hook: runs lint + format on backend files after any Edit/Write.
INPUT=$(cat)

if ! echo "$INPUT" | grep -q "backend"; then
  exit 0
fi

if [ -s "$HOME/.nvm/nvm.sh" ]; then
  # shellcheck disable=SC1091
  source "$HOME/.nvm/nvm.sh"
fi

echo "[post-edit] Lint + format backend..."
npm run lint --prefix backend || true
npm run format --prefix backend || true
echo "[post-edit] Done."
