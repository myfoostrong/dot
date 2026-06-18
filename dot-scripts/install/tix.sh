#!/bin/bash
# tix.sh — set up the single-Obsidian-vault planning store on this machine.
# Idempotent. Safe to re-run.

set -euo pipefail

# 1. Require $OBSIDIAN_VAULT_NAME — we resolve the absolute path at runtime
#    from Obsidian's per-machine registry, so this install does NOT need the
#    path itself, only the vault name.
if [ -z "${OBSIDIAN_VAULT_NAME:-}" ]; then
  echo "tix install: \$OBSIDIAN_VAULT_NAME is not set." >&2
  echo "  Export it to the name of your Obsidian vault and re-run, e.g.:" >&2
  echo "    OBSIDIAN_VAULT_NAME=MyVault bash dot-scripts/install/tix.sh" >&2
  exit 1
fi

# 2. jq is required by __tix_resolve_vault at runtime; warn now if missing.
if ! command -v jq >/dev/null 2>&1; then
  echo "tix install: jq not found. Install it before using 'tix' (apt install jq / brew install jq / pacman -S jq)." >&2
fi

# 3. Ensure .zshrc sources tix.zsh.
if ! grep -q 'dot-scripts/tix/tix.zsh' "$HOME/.zshrc"; then
  {
    echo ''
    echo '#### tix — single Obsidian vault planning store'
    echo '[[ -r "$HOME/dot-scripts/tix/tix.zsh" ]] && source "$HOME/dot-scripts/tix/tix.zsh"'
  } >> "$HOME/.zshrc"
fi

# 4. Persist OBSIDIAN_VAULT_NAME in .zshrc if it's not already set there.
if ! grep -q 'OBSIDIAN_VAULT_NAME=' "$HOME/.zshrc"; then
  printf 'export OBSIDIAN_VAULT_NAME=%q\n' "${OBSIDIAN_VAULT_NAME}" >> "$HOME/.zshrc"
fi

# 5. Eagerly resolve the vault now to fail fast on first install if the
#    name does not match anything in Obsidian's registry. This sources the
#    fragment in a subshell rather than relying on the user's .zshrc state.
if ! resolved=$(
  OBSIDIAN_VAULT_NAME="$OBSIDIAN_VAULT_NAME" \
    zsh -c "source $HOME/dot-scripts/tix/tix.zsh && __tix_resolve_vault" 2>&1
); then
  echo "tix install: could not resolve vault now, but .zshrc is configured." >&2
  echo "  Detail: $resolved" >&2
  echo "  Open Obsidian once with the '$OBSIDIAN_VAULT_NAME' vault, then re-run." >&2
  exit 1
fi

# 6. Ensure the per-repo root exists in the resolved vault.
mkdir -p "${resolved}/repos"

echo "tix install: vault='${OBSIDIAN_VAULT_NAME}' resolved to ${resolved}, .zshrc updated."
echo "  Open a new shell, cd into any repo, and run 'tix init'."
