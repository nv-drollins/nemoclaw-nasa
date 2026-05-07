#!/usr/bin/env bash
set -euo pipefail

TOKEN_FILE="${1:-/tmp/openclaw-token}"

if [ ! -f "$TOKEN_FILE" ]; then
  echo "Token file not found: $TOKEN_FILE" >&2
  exit 1
fi

TOKEN="$(cat "$TOKEN_FILE")"

openclaw gateway stop || true
sleep 3

openclaw config set agents.defaults.timeoutSeconds 600 >/dev/null
openclaw config set agents.defaults.thinkingDefault off >/dev/null || true
openclaw config set agents.defaults.experimental.localModelLean true >/dev/null || true

if pgrep -f '^openclaw-gateway$' >/dev/null 2>&1; then
  pkill -TERM -f '^openclaw-gateway$' || true
  for _ in $(seq 1 20); do
    if ! pgrep -f '^openclaw-gateway$' >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi

if pgrep -f '^openclaw-gateway$' >/dev/null 2>&1; then
  pkill -KILL -f '^openclaw-gateway$' || true
  sleep 1
fi

pkill -TERM -f '^openclaw$' || true
sleep 1

PATH="/sandbox/bin:$PATH" nohup openclaw gateway run \
  --allow-unconfigured --dev \
  --bind loopback --port 18789 \
  --token "$TOKEN" \
  >/tmp/gateway.log 2>&1 &

for _ in $(seq 1 30); do
  if openclaw gateway health >/dev/null 2>&1; then
    echo "OpenClaw gateway restarted"
    exit 0
  fi
  sleep 1
done

echo "OpenClaw gateway did not report healthy within 30 seconds" >&2
tail -80 /tmp/gateway.log >&2 || true
exit 1
