#!/usr/bin/env bash
# Run the Diana worker in the foreground (for testing).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if [ ! -f "$REPO_ROOT/deploy/pi/env" ]; then
    echo "Missing $REPO_ROOT/deploy/pi/env - copy env.example and fill it in first." >&2
    exit 1
fi

set -a
# shellcheck disable=SC1091
source "$REPO_ROOT/deploy/pi/env"
set +a

cd "$REPO_ROOT/apps/worker"
exec uv run python -m worker.entrypoints.worker
