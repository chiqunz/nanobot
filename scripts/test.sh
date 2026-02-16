#!/usr/bin/env bash
# Run tests
set -euo pipefail

cd "$(dirname "$0")/.."

poetry run pytest "$@"
