#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=resolve-demo-root.sh
. "$SCRIPT_DIR/resolve-demo-root.sh"
ROOT="$(resolve_demo_root "$SCRIPT_DIR")"
SANDBOX="${1:-${NEMOCLAW_SANDBOX_NAME:-apod-agent}}"
SKILLS_BASE="/sandbox/.openclaw/skills"
SESSIONS_PATH="/sandbox/.openclaw-data/agents/main/sessions/sessions.json"
SSH_CONFIG="/tmp/${SANDBOX}.ssh_config"

export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

usage() {
  cat <<EOF
Usage: $0 [sandbox-name]

Installs the NASA APOD OpenClaw skill into a NemoClaw sandbox:
  - applies the api.nasa.gov network policy
  - copies the nasa-apod skill into the sandbox
  - clears stale OpenClaw sessions
  - restarts the OpenClaw gateway
  - verifies the skill and NASA API access from inside the sandbox

Default sandbox: $SANDBOX
EOF
}

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

need openshell
need nemoclaw
need ssh
need scp
need python3

if [ ! -f "$ROOT/skills/nasa-apod/SKILL.md" ]; then
  echo "NASA APOD skill not found at $ROOT/skills/nasa-apod/SKILL.md" >&2
  exit 1
fi

if ! openshell sandbox get "$SANDBOX" >/dev/null 2>&1; then
  echo "Sandbox '$SANDBOX' was not found. Run ./scripts/onboard-nemoclaw.sh first." >&2
  exit 1
fi

echo "[1/5] Applying NASA APOD network policy"
CURRENT_POLICY="$(openshell policy get "$SANDBOX" --full 2>/dev/null | sed '1,/^---$/d' || true)"
POLICY_FILE="$(mktemp /tmp/nasa-apod-policy-XXXX.yaml)"

if printf '%s\n' "$CURRENT_POLICY" | grep -q "nasa_apod"; then
  echo "Policy already contains nasa_apod"
  rm -f "$POLICY_FILE"
else
  printf '%s\n' "$CURRENT_POLICY" | python3 -c '
import sys

policy = sys.stdin.read().rstrip()
nasa_block = """  nasa_apod:
    name: nasa_apod
    endpoints:
    - host: api.nasa.gov
      port: 443
      protocol: rest
      tls: passthrough
      enforcement: enforce
      rules:
      - allow:
          method: GET
          path: /planetary/apod
    binaries:
    - path: /usr/bin/curl
    - path: /usr/local/bin/node
"""

print(policy + "\n" + nasa_block)
' > "$POLICY_FILE"
  openshell policy set "$SANDBOX" --policy "$POLICY_FILE" --wait >/dev/null
  rm -f "$POLICY_FILE"
fi

openshell sandbox ssh-config "$SANDBOX" > "$SSH_CONFIG"

echo "[2/5] Uploading NASA APOD skill"
ssh -F "$SSH_CONFIG" "openshell-$SANDBOX" mkdir -p "$SKILLS_BASE/nasa-apod"
scp -F "$SSH_CONFIG" "$ROOT/skills/nasa-apod/SKILL.md" \
  "openshell-$SANDBOX:$SKILLS_BASE/nasa-apod/SKILL.md" >/dev/null

echo "[3/5] Clearing OpenClaw sessions"
ssh -F "$SSH_CONFIG" "openshell-$SANDBOX" \
  "[ -f '$SESSIONS_PATH' ] && echo '{}' > '$SESSIONS_PATH' || true"

echo "[4/5] Restarting OpenClaw gateway"
TOKEN_FILE="$(mktemp /tmp/openclaw-token-XXXX)"
nemoclaw "$SANDBOX" gateway-token --quiet > "$TOKEN_FILE"
scp -F "$SSH_CONFIG" "$TOKEN_FILE" "openshell-$SANDBOX:/tmp/openclaw-token" >/dev/null
scp -F "$SSH_CONFIG" "$ROOT/scripts/restart-openclaw-gateway.sh" \
  "openshell-$SANDBOX:/tmp/restart-openclaw-gateway.sh" >/dev/null
ssh -F "$SSH_CONFIG" "openshell-$SANDBOX" bash /tmp/restart-openclaw-gateway.sh /tmp/openclaw-token
rm -f "$TOKEN_FILE"

echo "[5/5] Verifying APOD access"
ssh -F "$SSH_CONFIG" "openshell-$SANDBOX" test -f "$SKILLS_BASE/nasa-apod/SKILL.md"
API_TITLE="$(ssh -F "$SSH_CONFIG" "openshell-$SANDBOX" \
  "curl -sf 'https://api.nasa.gov/planetary/apod?api_key=DEMO_KEY' | python3 -c 'import json,sys; print(json.load(sys.stdin).get(\"title\", \"\"))'" \
  2>/dev/null || true)"

if [ -z "$API_TITLE" ]; then
  echo "NASA API check did not return a title. The DEMO_KEY may be rate-limited; the skill is installed." >&2
else
  echo "NASA API reachable: $API_TITLE"
fi

cat <<EOF

NASA APOD demo is installed in sandbox '$SANDBOX'.

Open the dashboard URL and token with:
  ./scripts/show-openclaw-dashboard.sh --sandbox $SANDBOX --show-token

Try this prompt in OpenClaw:
  What is the NASA Astronomy Picture of the Day today? Include the title, date, media type, and image or video URL.
EOF
