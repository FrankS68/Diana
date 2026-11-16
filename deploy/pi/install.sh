#!/usr/bin/env bash
# Diana planets.nu worker - setup for Raspberry Pi (64-bit) / any Linux box.
set -euo pipefail

cd "$(dirname "$0")/../../apps/worker"

if ! command -v uv >/dev/null 2>&1; then
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

uv python install 3.12
uv sync

echo
echo "Setup complete. Next:"
echo "  1. cp deploy/pi/env.example deploy/pi/env   (from the repo root)"
echo "  2. Fill in MISTRAL_API_KEY and PLANETSNU_API_KEY in deploy/pi/env"
echo "  3. Test run:  bash deploy/pi/run.sh"
