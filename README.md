# NemoClaw NASA APOD Demo

Self-contained NemoClaw/OpenClaw demo that lets a local agent fetch NASA's Astronomy Picture of the Day directly from `api.nasa.gov`.

This repo includes the NemoClaw onboarding wrapper, the APOD skill, the APOD network policy, dashboard URL/token helper, smoke test, and stop/start scripts. No Blender repo or external demo checkout is required.

## Before You Begin

Use an Ubuntu host with:

- NVIDIA GPU drivers and the NVIDIA Container Toolkit
- Docker
- Ollama running on port `11434`
- `git`, `curl`, `python3`, `ssh`, and `scp`
- Passwordless sudo for the user running the demo

Pull the local model first:

```bash
ollama pull nemotron-3-nano:30b
```

NASA APOD uses NASA's public `DEMO_KEY`; no NASA account or secret is required.

## Quick Start

```bash
git clone https://github.com/nv-drollins/nemoclaw-nasa.git
cd nemoclaw-nasa

NEMOCLAW_MODEL=nemotron-3-nano:30b ./scripts/onboard-nemoclaw.sh
./scripts/start-demo.sh
```

`start-demo.sh` installs or refreshes the APOD policy and skill, restarts the OpenClaw gateway, and prints the dashboard URL and token.

Open the dashboard URL, paste the token when prompted, then try this prompt:

```text
What is the NASA Astronomy Picture of the Day today? Include the title, date, media type, and image or video URL.
```

## What The Scripts Do

### NemoClaw onboarding

```bash
NEMOCLAW_MODEL=nemotron-3-nano:30b ./scripts/onboard-nemoclaw.sh
```

This installs NemoClaw/OpenShell/OpenClaw, creates the sandbox, configures Ollama as the local inference provider, checks NVIDIA CDI GPU passthrough, and avoids optional router install paths that can trip Python externally-managed-environment errors.

Default sandbox name:

```bash
apod-agent
```

Use a different sandbox name with:

```bash
NEMOCLAW_SANDBOX_NAME=my-apod-agent NEMOCLAW_MODEL=nemotron-3-nano:30b ./scripts/onboard-nemoclaw.sh
```

### Install or refresh APOD only

```bash
./scripts/install-apod-skill.sh apod-agent
```

This applies the `api.nasa.gov` network policy, uploads `skills/nasa-apod/SKILL.md` into the sandbox, clears stale sessions, restarts the OpenClaw gateway, and verifies API access from inside the sandbox.

The root wrapper does the same thing:

```bash
./install.sh apod-agent
```

### Show dashboard URL and token

```bash
./scripts/show-openclaw-dashboard.sh --show-token
```

Without `--show-token`, the script prints the dashboard URL and the command to retrieve the token.

### Smoke test

```bash
./scripts/run-apod-agent-smoke.sh
```

Or run it during startup:

```bash
./scripts/start-demo.sh --smoke
```

## Stop And Restart

Stop the OpenClaw gateway but keep the sandbox:

```bash
./scripts/stop-demo.sh
```

Start it again:

```bash
./scripts/start-demo.sh
```

Destroy the sandbox and its persistent volume:

```bash
./scripts/stop-demo.sh --destroy-sandbox
```

After destroying the sandbox, run onboarding again before starting the demo.

## Troubleshooting

If onboarding reports missing CDI specs, generate them and rerun onboarding:

```bash
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
nvidia-ctk cdi list
```

If APOD calls fail after several demos, NASA's public `DEMO_KEY` may be temporarily rate-limited from your IP. Wait for the limit to reset or update the skill to use your own NASA API key.

Check NemoClaw status:

```bash
nemoclaw apod-agent status
```

Print the dashboard URL and token again:

```bash
./scripts/show-openclaw-dashboard.sh --show-token
```
