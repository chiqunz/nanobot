#!/usr/bin/env bash
#
# Auto-fix all formatting and linting issues in the nanobot repository.
#
# Usage:
#   ./scripts/format.sh          # fix everything
#   ./scripts/format.sh --check  # dry-run, exit non-zero if changes needed
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCES=("nanobot" "tests")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { printf "${GREEN}✔${RESET} %s\n" "$*"; }
warn()  { printf "${YELLOW}⚠${RESET} %s\n" "$*"; }
fail()  { printf "${RED}✖${RESET} %s\n" "$*"; }

# ---------------------------------------------------------------------------
# Ensure ruff is available
# ---------------------------------------------------------------------------
if ! command -v ruff &>/dev/null; then
    echo "ruff not found — attempting install …"
    if command -v poetry &>/dev/null && [ -f "$REPO_ROOT/poetry.lock" ]; then
        poetry run pip install ruff
        RUFF="poetry run ruff"
    elif command -v uv &>/dev/null; then
        uv pip install ruff
        RUFF="ruff"
    else
        pip install ruff
        RUFF="ruff"
    fi
else
    RUFF="ruff"
fi

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
CHECK_ONLY=false
for arg in "$@"; do
    case "$arg" in
        --check|-c) CHECK_ONLY=true ;;
        --help|-h)
            echo "Usage: $0 [--check]"
            echo "  --check   dry-run mode; exit 1 if any changes are needed"
            exit 0
            ;;
    esac
done

cd "$REPO_ROOT"

EXIT_CODE=0

# ---------------------------------------------------------------------------
# Step 1: Strip trailing whitespace from blank lines (W293)
# ---------------------------------------------------------------------------
if $CHECK_ONLY; then
    # Check for blank lines that contain only whitespace
    if grep -rn '^[[:space:]]\+$' "${SOURCES[@]}" --include='*.py' >/dev/null 2>&1; then
        fail "Blank lines with trailing whitespace found"
        EXIT_CODE=1
    else
        info "No trailing whitespace on blank lines"
    fi
else
    # macOS and GNU sed have different in-place syntax; detect which we have
    if sed --version 2>/dev/null | grep -q GNU; then
        find "${SOURCES[@]}" -name '*.py' -exec sed -i 's/^[[:space:]]*$//' {} +
    else
        find "${SOURCES[@]}" -name '*.py' -exec sed -i '' 's/^[[:space:]]*$//' {} +
    fi
    info "Stripped trailing whitespace from blank lines"
fi

# ---------------------------------------------------------------------------
# Step 2: Ruff auto-fix (import sorting, unused imports, whitespace, etc.)
# ---------------------------------------------------------------------------
if $CHECK_ONLY; then
    echo ""
    printf "${BOLD}Running ruff check …${RESET}\n"
    if $RUFF check "${SOURCES[@]}"; then
        info "ruff: all checks passed"
    else
        EXIT_CODE=1
    fi
else
    echo ""
    printf "${BOLD}Running ruff check --fix …${RESET}\n"
    $RUFF check --fix "${SOURCES[@]}" || true
    info "ruff auto-fix complete"
fi

# ---------------------------------------------------------------------------
# Step 3: Ruff format (code style — consistent quotes, trailing commas, etc.)
# ---------------------------------------------------------------------------
if $CHECK_ONLY; then
    echo ""
    printf "${BOLD}Running ruff format --check …${RESET}\n"
    if $RUFF format --check "${SOURCES[@]}"; then
        info "ruff format: no changes needed"
    else
        fail "ruff format: files would be reformatted"
        EXIT_CODE=1
    fi
else
    echo ""
    printf "${BOLD}Running ruff format …${RESET}\n"
    $RUFF format "${SOURCES[@]}"
    info "ruff format complete"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
if [ $EXIT_CODE -eq 0 ]; then
    if $CHECK_ONLY; then
        printf "${GREEN}${BOLD}All format checks passed.${RESET}\n"
    else
        printf "${GREEN}${BOLD}All formatting fixes applied.${RESET}\n"
    fi
else
    printf "${RED}${BOLD}Some checks failed — run ./scripts/format.sh to fix.${RESET}\n"
fi

exit $EXIT_CODE
