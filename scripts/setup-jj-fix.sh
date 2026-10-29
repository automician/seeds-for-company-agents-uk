#!/usr/bin/env bash
# Symlink jj's per-repo config path to the in-repo source of truth
# (seeds-for-company-agents-uk/jj-fix.config.toml). Idempotent: re-running is safe and reports
# the current state without redoing work.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_ROOT/jj-fix.config.toml"

log() { printf '  %s\n' "$1"; }
ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }
err() {
  printf '  \033[31m✗\033[0m %s\n' "$1" >&2
  exit 1
}

echo "seeds-for-company-agents-uk :: setup jj fix tooling"

# 1. Source file must exist
[ -f "$SRC" ] || err "source not found: $SRC"
ok "source config: $SRC"

# 2. jj must be on PATH
command -v jj >/dev/null 2>&1 ||
  err "jj not found in PATH (install: https://jj-vcs.github.io/jj/)"
ok "jj present ($(jj --version))"

# 3. oxfmt is referenced by the config; warn (don't fail) if not yet installed
OXFMT="$REPO_ROOT/node_modules/.bin/oxfmt"
if [ -x "$OXFMT" ]; then
  ok "oxfmt present: $OXFMT"
else
  warn "oxfmt missing at $OXFMT — run 'pnpm install' before 'jj fix'"
fi

# 4. Destination: per-repo config path managed by jj (opaque hash dir)
DST="$(jj config path --repo)"
DST_DIR="$(dirname "$DST")"
if [ -d "$DST_DIR" ]; then
  ok "config dir exists: $DST_DIR"
else
  mkdir -p "$DST_DIR"
  ok "created config dir: $DST_DIR"
fi

# 5. Decide what to do based on what is already at DST
if [ -L "$DST" ]; then
  CURRENT_TARGET="$(readlink "$DST")"
  if [ "$CURRENT_TARGET" = "$SRC" ]; then
    ok "symlink already points to source — nothing to do"
    echo "seeds-for-company-agents-uk :: setup complete"
    exit 0
  fi
  warn "symlink points elsewhere ($CURRENT_TARGET) — replacing"
elif [ -e "$DST" ]; then
  BACKUP="$DST.bak.$(date +%Y%m%d%H%M%S)"
  cp "$DST" "$BACKUP"
  warn "regular file existed at $DST — backed up to $BACKUP"
else
  log "no existing config at $DST"
fi

# 6. Create/replace the symlink
ln -sfn "$SRC" "$DST"
ok "symlink: $DST -> $SRC"

# 7. Verify jj actually reads our config
if jj config get fix.tools.oxfmt.command >/dev/null 2>&1; then
  ok "jj reads fix.tools.oxfmt.command"
else
  err "jj could not read fix.tools.oxfmt.command after symlink"
fi

echo "seeds-for-company-agents-uk :: setup complete"
