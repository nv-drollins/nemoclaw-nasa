#!/usr/bin/env bash
set -euo pipefail

SANDBOX="${NEMOCLAW_SANDBOX_NAME:-apod-agent}"
DESTROY_SANDBOX=0

usage() {
  cat <<EOF
Usage: $0 [--sandbox NAME] [--destroy-sandbox]

Stops the APOD demo gateway inside the NemoClaw sandbox.

Options:
  --sandbox NAME      NemoClaw sandbox name. Default: $SANDBOX
  --destroy-sandbox   Permanently destroy the sandbox and its volume.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --sandbox)
      SANDBOX="${2:?missing sandbox name}"
      shift
      ;;
    --destroy-sandbox) DESTROY_SANDBOX=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

if command -v openshell >/dev/null 2>&1; then
  SSH_CONFIG="/tmp/${SANDBOX}.ssh_config"
  if openshell sandbox ssh-config "$SANDBOX" > "$SSH_CONFIG" 2>/dev/null; then
    echo "Stopping OpenClaw gateway in sandbox $SANDBOX"
    ssh -F "$SSH_CONFIG" "openshell-$SANDBOX" openclaw gateway stop || true
  else
    echo "Could not resolve sandbox SSH config for $SANDBOX"
  fi
else
  echo "openshell is not on PATH; skipping gateway stop"
fi

if [ "$DESTROY_SANDBOX" -eq 1 ]; then
  if ! command -v nemoclaw >/dev/null 2>&1; then
    echo "Sandbox destroy requested, but nemoclaw is not on PATH" >&2
    exit 1
  fi
  echo "Destroying sandbox $SANDBOX. This deletes its persistent volume."
  nemoclaw "$SANDBOX" destroy --yes
fi

echo "APOD demo stopped."
