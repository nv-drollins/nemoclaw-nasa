#!/usr/bin/env bash
set -euo pipefail

SANDBOX="${NEMOCLAW_SANDBOX_NAME:-apod-agent}"
PROMPT="What is the NASA Astronomy Picture of the Day today? Include the title, date, media type, and image or video URL."

usage() {
  cat <<EOF
Usage: $0 [--sandbox NAME]

Runs a simple OpenClaw APOD prompt inside the NemoClaw sandbox.
Default sandbox: $SANDBOX
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --sandbox)
      SANDBOX="${2:?missing sandbox name}"
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

SSH_CONFIG="/tmp/${SANDBOX}.ssh_config"
RUNNER="$(mktemp /tmp/nasa-apod-smoke-XXXX.sh)"
cleanup() {
  rm -f "$RUNNER"
}
trap cleanup EXIT

openshell sandbox ssh-config "$SANDBOX" > "$SSH_CONFIG"

cat > "$RUNNER" <<EOF
#!/usr/bin/env bash
set -euo pipefail
env NODE_NO_WARNINGS=1 openclaw agent \\
  --session-id nasa-apod-smoke \\
  --message "$PROMPT" \\
  --timeout 600
EOF

scp -F "$SSH_CONFIG" "$RUNNER" "openshell-$SANDBOX:/tmp/nasa-apod-smoke.sh" >/dev/null
ssh -F "$SSH_CONFIG" "openshell-$SANDBOX" bash /tmp/nasa-apod-smoke.sh
