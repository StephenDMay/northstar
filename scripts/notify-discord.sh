#!/usr/bin/env bash
# Posts a message to the team Discord channel via webhook.
# Usage: scripts/notify-discord.sh "<message>"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

# Worktrees (e.g. /fleet sessions) don't get the gitignored .env — fall back
# to the main checkout's copy.
if [ ! -f "$ENV_FILE" ]; then
  COMMON_DIR="$(git -C "$SCRIPT_DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [ -n "$COMMON_DIR" ] && ENV_FILE="$(dirname "$COMMON_DIR")/.env"
fi

if [ -f "$ENV_FILE" ]; then
  # Line-by-line parse, not `source` — values may contain characters
  # (&, ?, etc) that a shell `source` would misinterpret.
  while IFS='=' read -r key value; do
    [ -z "$key" ] && continue
    case "$key" in \#*) continue ;; esac
    if [ -z "${!key:-}" ]; then
      export "$key=$value"
    fi
  done < "$ENV_FILE"
fi

if [ -z "${DISCORD_WEBHOOK_URL:-}" ]; then
  echo "DISCORD_WEBHOOK_URL is not set (checked shell env and .env) — skipping Discord notification" >&2
  exit 0
fi

if [ $# -lt 1 ] || [ -z "$1" ]; then
  echo "usage: $0 \"<message>\"" >&2
  exit 1
fi

payload=$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps({"content": sys.stdin.read()}))')

curl -sf -X POST -H "Content-Type: application/json" -d "$payload" "$DISCORD_WEBHOOK_URL" > /dev/null
