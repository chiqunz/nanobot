#!/usr/bin/env bash
# Build the package
set -euo pipefail

cd "$(dirname "$0")/.."

poetry build
