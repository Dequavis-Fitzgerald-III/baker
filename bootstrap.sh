#!/bin/bash
# =============================================================================
# MojOS Bootstrap
# Single entry point — clones the repo and runs install.sh from the clone.
# Usage: curl -fsSL https://raw.githubusercontent.com/Dequavis-Fitzgerald-III/mojos/main/bootstrap.sh | bash
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

REPO_URL="https://github.com/Dequavis-Fitzgerald-III/mojos.git"
CLONE_DIR="/tmp/mojos"

command -v git >/dev/null 2>&1 || error "git is not available on this ISO."

if [[ -d "$CLONE_DIR/.git" ]]; then
    info "Repo already at $CLONE_DIR — pulling latest..."
    git -C "$CLONE_DIR" pull
else
    info "Cloning MojOS..."
    git clone "$REPO_URL" "$CLONE_DIR"
fi

success "Repo ready at $CLONE_DIR"

exec bash "$CLONE_DIR/install.sh"
