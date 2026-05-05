#!/bin/bash
# =============================================================================
# mojo-init.sh — Make this OS yours
# Clones or creates your MojOS fork and writes identity to ~/.mojo_config.
# Called from post-install.sh after gh auth login.
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
section() { echo -e "\n${BOLD}=== $1 ===${NC}\n"; }

MOJO_CONFIG="$HOME/.mojo_config"
PROJECTS_DIR="$HOME/projects"

[[ -f "$MOJO_CONFIG" ]] || error ".mojo_config not found — run this after a fresh install."

write_identity() {
    local tmp
    tmp=$(mktemp)
    cp "$MOJO_CONFIG" "$tmp"
    awk -v user="$MOJO_USER" -v os="$OS_NAME" -v slug="$REPO_SLUG" -v dir="$FORK_DIR" \
        '/^# --- Hardware/{
            print "# --- Identity ---"
            print "MOJO_USER=" user
            print "OS_NAME=" os
            print "REPO_SLUG=" slug
            print "FORK_DIR=" dir
            print ""
        }
        { print }' "$tmp" > "$MOJO_CONFIG"
    rm -f "$tmp"
    success "Identity written to .mojo_config"
}

# =============================================================================
# PATH SELECTION
# =============================================================================
section "MojOS Init"
echo "Do you have an existing MojOS fork?"
echo "  1) Yes — clone my existing fork"
echo "  2) No  — create a new fork now"
echo ""
read -rp "Choice [1/2]: " PATH_INPUT
case "$PATH_INPUT" in
    1) PATH_CHOICE="existing" ;;
    2) PATH_CHOICE="new"      ;;
    *) error "Invalid choice." ;;
esac

# =============================================================================
# PATH A — existing fork
# =============================================================================
if [[ "$PATH_CHOICE" == "existing" ]]; then
    section "Clone Existing Fork"

    read -rp "Fork URL (e.g. https://github.com/you/your-os): " FORK_URL
    [[ -z "$FORK_URL" ]] && error "Fork URL is required."

    REPO_SLUG=$(basename "$FORK_URL" .git)
    FORK_DIR="$PROJECTS_DIR/$REPO_SLUG"

    if [[ -d "$FORK_DIR/.git" ]]; then
        info "Fork already at $FORK_DIR — pulling latest..."
        git -C "$FORK_DIR" pull
    else
        info "Cloning $FORK_URL..."
        git clone "$FORK_URL" "$FORK_DIR"
    fi
    success "Fork ready at $FORK_DIR"

    git -C "$FORK_DIR" remote set-url upstream https://github.com/Dequavis-Fitzgerald-III/mojos.git 2>/dev/null \
        || git -C "$FORK_DIR" remote add upstream https://github.com/Dequavis-Fitzgerald-III/mojos.git
    success "upstream remote set"

    # Read identity from *.conf in fork root
    CONF_FILE=$(find "$FORK_DIR" -maxdepth 1 -name "*.conf" | head -n1)
    [[ -z "$CONF_FILE" ]] && error "No .conf file found in fork root — is this a MojOS fork?"

    # shellcheck source=/dev/null
    source "$CONF_FILE"

    [[ -z "$MOJO_USER" ]] && error "MOJO_USER not set in $(basename "$CONF_FILE")."
    [[ -z "$OS_NAME"   ]] && error "OS_NAME not set in $(basename "$CONF_FILE")."
    [[ -z "$REPO_SLUG" ]] && error "REPO_SLUG not set in $(basename "$CONF_FILE")."

    success "Identity loaded: $MOJO_USER / $OS_NAME"
    write_identity

# =============================================================================
# PATH B — new fork
# =============================================================================
else
    section "Create New Fork"

    read -rp "Your MojOS username (e.g. the_baker): " MOJO_USER
    [[ -z "$MOJO_USER" ]] && error "Username is required."

    read -rp "OS name (e.g. BakerOS): " OS_NAME
    [[ -z "$OS_NAME" ]] && error "OS name is required."

    read -rp "GitHub repo slug (e.g. baker): " REPO_SLUG
    [[ -z "$REPO_SLUG" ]] && error "Repo slug is required."

    FORK_DIR="$PROJECTS_DIR/$REPO_SLUG"

    info "Forking mojos as $REPO_SLUG..."
    gh repo fork Dequavis-Fitzgerald-III/mojos --clone=false --private --fork-name "$REPO_SLUG"
    success "Fork created on GitHub"

    GH_USER=$(gh api user --jq .login)
    info "Cloning fork..."
    git clone "https://github.com/$GH_USER/$REPO_SLUG.git" "$FORK_DIR"
    success "Fork cloned to $FORK_DIR"

    git -C "$FORK_DIR" remote set-url upstream https://github.com/Dequavis-Fitzgerald-III/mojos.git 2>/dev/null \
        || git -C "$FORK_DIR" remote add upstream https://github.com/Dequavis-Fitzgerald-III/mojos.git
    success "upstream remote set"

    # Scaffold identity conf
    cat > "$FORK_DIR/$MOJO_USER.conf" <<CONF
MOJO_USER=$MOJO_USER
OS_NAME=$OS_NAME
REPO_SLUG=$REPO_SLUG
CONF
    success "$MOJO_USER.conf created"

    # Scaffold personal package manifest
    mkdir -p "$FORK_DIR/packages/user"
    cat > "$FORK_DIR/packages/user/$MOJO_USER.txt" <<PKG
[pacman]

[aur]

[flatpak]
PKG
    success "packages/user/$MOJO_USER.txt created"

    if [[ -n "$EDITOR" ]]; then
        info "Opening package manifest in $EDITOR — add your personal packages..."
        "$EDITOR" "$FORK_DIR/packages/user/$MOJO_USER.txt"
    else
        warn "EDITOR not set — edit $FORK_DIR/packages/user/$MOJO_USER.txt manually"
    fi

    git -C "$FORK_DIR" add "$MOJO_USER.conf" "packages/user/$MOJO_USER.txt"
    git -C "$FORK_DIR" commit -m "feat: scaffold $OS_NAME identity and package manifest"
    git -C "$FORK_DIR" push
    success "Fork initialised and pushed"

    write_identity
fi

# =============================================================================
# DONE
# =============================================================================
section "Done"
success "$OS_NAME is set up at $FORK_DIR"
info "Run mojo-update at any time to converge to the latest MojOS."
