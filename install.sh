#!/bin/bash
# install.sh - symlink njslyr7 into the expected runtime locations.
#
# Idempotent. Re-run after pulling updates.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="${NJSLYR_HOME:-$HOME/.njslyr7}"
BIN_DIR="${LOCAL_BIN:-$HOME/.local/bin}"
SKILL_DIR="${CLAUDE_SKILLS:-$HOME/.claude/skills}"

mkdir -p "$RUNTIME_DIR/mailbox/cursor" "$RUNTIME_DIR/formation" "$BIN_DIR" "$SKILL_DIR"
touch "$RUNTIME_DIR/mailbox/log.jsonl" "$RUNTIME_DIR/formation/registry.jsonl"

ln -sfn "$REPO_DIR/bin/formation"        "$BIN_DIR/formation"
ln -sfn "$REPO_DIR/skills/formation"     "$SKILL_DIR/formation"

echo "installed:"
echo "  $BIN_DIR/formation   -> $REPO_DIR/bin/formation"
echo "  $SKILL_DIR/formation -> $REPO_DIR/skills/formation"
echo "runtime state: $RUNTIME_DIR"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "warn: $BIN_DIR not on PATH. Add it to your shell rc." ;;
esac
