#!/usr/bin/env bash
# Run linting and formatting
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== Lint check ==="
poetry run ruff check nanobot/

echo ""
echo "=== Format check ==="
poetry run ruff format --check nanobot/

# Pass --fix to auto-fix issues
if [[ "${1:-}" == "--fix" ]]; then
    echo ""
    echo "=== Auto-fixing ==="
    poetry run ruff check --fix nanobot/
    poetry run ruff format nanobot/
fi
