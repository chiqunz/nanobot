#!/usr/bin/env bash
# Setup the project with Poetry (Python 3.11+)
set -euo pipefail

cd "$(dirname "$0")/.."

# Find a suitable Python 3.11+
if command -v python3.12 &> /dev/null; then
    PYTHON=python3.12
elif command -v python3.11 &> /dev/null; then
    PYTHON=python3.11
else
    python_version=$(python3 --version 2>&1 | sed 's/Python \([0-9]*\.[0-9]*\).*/\1/')
    major=$(echo "$python_version" | cut -d. -f1)
    minor=$(echo "$python_version" | cut -d. -f2)
    if [[ "$major" -lt 3 ]] || { [[ "$major" -eq 3 ]] && [[ "$minor" -lt 11 ]]; }; then
        echo "Error: Python 3.11+ required (found $python_version)"
        echo "Install it with: brew install python@3.12"
        exit 1
    fi
    PYTHON=python3
fi
echo "Using Python: $($PYTHON --version)"

# Check if poetry is installed
if ! command -v poetry &> /dev/null; then
    echo "Installing Poetry..."
    curl -sSL https://install.python-poetry.org | python3 -
fi

# Configure poetry to use in-project virtualenv
poetry config virtualenvs.in-project true

# Tell Poetry which Python to use
poetry env use "$PYTHON"

# Install all dependencies including dev group
poetry install --with dev

echo ""
echo "Setup complete! Activate the environment with:"
echo "  poetry shell"
echo "Or prefix commands with:"
echo "  poetry run <command>"
