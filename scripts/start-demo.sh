#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOX="${NEMOCLAW_SANDBOX_NAME:-apod-agent}"
RUN_SMOKE=0
SHOW_TOKEN=1

usage() {
  cat <<EOF
Usage: $0 [--sandbox NAME] [--smoke] [--no-token]

Starts an already-onboarded NASA APOD NemoClaw demo:
  - verifies the sandbox exists
  - installs or refreshes the NASA APOD policy and skill
  - restarts the OpenClaw gateway
  - prints the dashboard URL and token

Options:
  --sandbox NAME   NemoClaw sandbox name. Default: $SANDBOX
  --smoke          Ask OpenClaw to fetch today's APOD after startup.
  --no-token       Print the dashboard URL without printing the token.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --sandbox)
      SANDBOX="${2:?missing sandbox name}"
      shift
      ;;
    --smoke) RUN_SMOKE=1 ;;
    --no-token) SHOW_TOKEN=0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
export NEMOCLAW_SANDBOX_NAME="$SANDBOX"

if ! command -v openshell >/dev/null 2>&1; then
  echo "Missing openshell. Run ./scripts/onboard-nemoclaw.sh first." >&2
  exit 1
fi

if ! openshell sandbox get "$SANDBOX" >/dev/null 2>&1; then
  echo "Sandbox '$SANDBOX' was not found. Run ./scripts/onboard-nemoclaw.sh first." >&2
  exit 1
fi

echo "[1/2] Installing NASA APOD skill and policy"
"$SCRIPT_DIR/install-apod-skill.sh" "$SANDBOX"

if [ "$RUN_SMOKE" -eq 1 ]; then
  echo
  echo "[smoke] Asking OpenClaw for today's APOD"
  "$SCRIPT_DIR/run-apod-agent-smoke.sh" --sandbox "$SANDBOX"
fi

echo
echo "[2/2] OpenClaw dashboard"
if [ "$SHOW_TOKEN" -eq 1 ]; then
  "$SCRIPT_DIR/show-openclaw-dashboard.sh" --sandbox "$SANDBOX" --show-token
else
  "$SCRIPT_DIR/show-openclaw-dashboard.sh" --sandbox "$SANDBOX"
fi
