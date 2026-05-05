#!/bin/bash
# =============================================================================
# MojOS Upgrade Script
# Converges a running MojOS machine to the current version.
# Safe to run at any time — all steps are idempotent.
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

FORK_DIR="$HOME/projects/baker"
MOJO_CONFIG="$HOME/.mojo_config"

[[ ! -d "$FORK_DIR/.git" ]] && error "Fork repo not found at $FORK_DIR. Has mojo-init been run?"
[[ ! -f "$MOJO_CONFIG" ]]   && error ".mojo_config not found at $MOJO_CONFIG. Has mojo-init been run?"

section "Pulling latest fork repo"
git -C "$FORK_DIR" pull
success "Fork repo up to date"

source "$MOJO_CONFIG"
info "Profile: $PROFILE | GPU: $GPU"

# Extracts a named [section] block from manifest content piped via stdin.
parse_section() {
    awk "/^\[$1\]/{found=1; next} /^\[/{found=0} found && !/^#/ && NF"
}

# =============================================================================
# SECTION 1 — SYSTEM UPGRADE
# =============================================================================
section "Upgrading system packages"
sudo pacman -Syu --noconfirm
success "System packages upgraded"

# =============================================================================
# SECTION 2 — PACMAN PACKAGES
# --needed skips packages already installed — safe to run on a live system.
# =============================================================================
section "Installing missing pacman packages"
mapfile -t PACMAN_PACKAGES < <(
    parse_section pacman < "$FORK_DIR/packages/base.txt"
    parse_section pacman < "$FORK_DIR/packages/profile/$PROFILE.txt"
    [[ "$GPU" != "none" ]] && parse_section pacman < "$FORK_DIR/packages/hardware/gpu-$GPU.txt"
)
sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"
success "Pacman packages up to date"

# =============================================================================
# SECTION 3 — AUR PACKAGES
# =============================================================================
section "Installing missing AUR packages"
mapfile -t AUR_PACKAGES < <(parse_section aur < "$FORK_DIR/packages/base.txt")
yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"
success "AUR packages up to date"

# =============================================================================
# SECTION 4 — FLATPAK PACKAGES
# =============================================================================
section "Installing missing Flatpak packages"
mapfile -t FLATPAK_PACKAGES < <(parse_section flatpak < "$FORK_DIR/packages/base.txt")
for pkg in "${FLATPAK_PACKAGES[@]}"; do
    flatpak install -y --noninteractive flathub "$pkg" || true
done
success "Flatpak packages up to date"

# =============================================================================
# SECTION 5 — DOTFILES
# =============================================================================
section "Updating dotfiles"

DOTFILES_DIR="$HOME/projects/dotfiles"

# Creates a symlink from dst (where the app looks) to src (file in dotfiles repo).
# Backs up any existing real file at dst before overwriting.
symlink() {
    local src="$1"
    local dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        warn "Backing up existing $dst to $dst.bak"
        mv "$dst" "$dst.bak"
    fi
    ln -sf "$src" "$dst"
    success "Linked $src → $dst"
}

sudo_symlink() {
    local src="$1"
    local dst="$2"
    sudo mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        warn "Backing up existing $dst to $dst.bak"
        sudo mv "$dst" "$dst.bak"
    fi
    sudo ln -sf "$src" "$dst"
    success "Linked $src → $dst"
}

# Pull the dotfiles repo (separate from the fork repo pulled at the top)
git -C "$DOTFILES_DIR" pull
symlink "$DOTFILES_DIR/bash/.bashrc"               "$HOME/.bashrc"
symlink "$DOTFILES_DIR/kitty/kitty.conf"           "$HOME/.config/kitty/kitty.conf"
symlink "$DOTFILES_DIR/kitty/mocha.conf"           "$HOME/.config/kitty/mocha.conf"
symlink "$DOTFILES_DIR/hypr/hyprland.conf"         "$HOME/.config/hypr/hyprland.conf"
symlink "$DOTFILES_DIR/waybar"                     "$HOME/.config/waybar"
symlink "$DOTFILES_DIR/dunst/dunstrc"              "$HOME/.config/dunst/dunstrc"
symlink "$DOTFILES_DIR/rofi/config.rasi"           "$HOME/.config/rofi/config.rasi"
sudo_symlink "$DOTFILES_DIR/grub/theme"            "/boot/grub/themes/mojo"
sudo_symlink "$DOTFILES_DIR/sddm/sddm.conf"        "/etc/sddm.conf"
hyprctl reload 2>/dev/null || true
success "Dotfiles up to date"

# =============================================================================
# SECTION 6 — SERVICES
# systemctl enable --now is a no-op if the service is already enabled and running.
# =============================================================================
section "Ensuring services are enabled"
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now sddm
sudo systemctl enable --now ufw
sudo systemctl enable --now sshd

systemctl --user enable --now pipewire
systemctl --user enable --now pipewire-pulse
systemctl --user enable --now wireplumber
if [[ "$PROFILE" == "laptop" ]]; then
    sudo systemctl enable --now tlp
    sudo systemctl enable --now bluetooth
fi
success "Services up to date"

# =============================================================================
# SECTION 8 — SYNC .mojo_config
# Re-detects hardware values from the live system and rewrites .mojo_config
# in canonical format. Editable values are preserved from the current file.
# =============================================================================
section "Syncing .mojo_config"

# GPU — check loaded modules first, fall back to lspci
if lsmod | grep -q "^nvidia " || lspci | grep -qi "vga.*nvidia"; then
    DETECTED_GPU="nvidia"
elif lsmod | grep -q "^amdgpu " || lspci | grep -qi "vga.*amd\|vga.*radeon"; then
    DETECTED_GPU="amd"
elif lsmod | grep -q "^i915 " || lspci | grep -qi "vga.*intel"; then
    DETECTED_GPU="intel"
else
    DETECTED_GPU="none"
fi

# LUKS — check if root filesystem sits on a crypt device
ROOT_SOURCE=$(findmnt -n -o SOURCE /)
ROOT_FS_TYPE=$(lsblk -no TYPE "$ROOT_SOURCE" 2>/dev/null)
if [[ "$ROOT_FS_TYPE" == "crypt" ]]; then
    DETECTED_LUKS=true
    # PKNAME gives the parent kernel device (e.g. sda3) regardless of mapper name
    CRYPT_PARENT=$(lsblk -no PKNAME "$ROOT_SOURCE" 2>/dev/null)
    DETECTED_LUKS_UUID=$(sudo blkid -s UUID -o value "/dev/$CRYPT_PARENT" 2>/dev/null || true)
else
    DETECTED_LUKS=false
    DETECTED_LUKS_UUID=""
fi

# DUAL_BOOT — check for Windows EFI files on the EFI partition
EFI_DIR=$(findmnt -n -o TARGET /boot/efi 2>/dev/null || findmnt -n -o TARGET /boot 2>/dev/null)
if ls "${EFI_DIR}/EFI/" 2>/dev/null | grep -qi "microsoft"; then
    DETECTED_DUAL_BOOT=true
else
    DETECTED_DUAL_BOOT=false
fi

# HDD — look for any fstab mount under /mnt/
DETECTED_HDD_MOUNT=$(awk '$2 ~ /^\/mnt\// {print $2}' /etc/fstab | head -1)
if [[ -n "$DETECTED_HDD_MOUNT" ]]; then
    DETECTED_HDD=true
else
    DETECTED_HDD=false
    DETECTED_HDD_MOUNT=""
fi

cat > "$MOJO_CONFIG" <<MOJOCONF
# =============================================================================
# MojOS Machine Configuration — ~/.mojo_config
# Edit values under SYSTEM CONFIG and IDENTITY and run mojo-update to apply.
# Values under HARDWARE are auto-detected — edits will be reset on next update.
# =============================================================================

# --- System Config (editable) ---
HOSTNAME=$HOSTNAME
TIMEZONE=$TIMEZONE
LOCALE=$LOCALE
KEYMAP=$KEYMAP
DOTFILES_URL=$DOTFILES_URL
GRUB_TIMEOUT=${GRUB_TIMEOUT:--1}

# --- Identity (editable) ---
MOJO_USER=$MOJO_USER
OS_NAME=$OS_NAME
REPO_SLUG=$REPO_SLUG
FORK_DIR=$FORK_DIR
MOJOCONF

{
    printf "\n# --- Hardware (auto-detected, do not edit) ---\n"
    printf "PROFILE=%s\nGPU=%s\n" "$PROFILE" "$DETECTED_GPU"
    if [[ "$DETECTED_LUKS" == true ]]; then
        printf "LUKS=true\nLUKS_UUID=%s\n" "$DETECTED_LUKS_UUID"
    else
        printf "LUKS=false\n"
    fi
    printf "DUAL_BOOT=%s\n" "$DETECTED_DUAL_BOOT"
    if [[ "$DETECTED_HDD" == true ]]; then
        printf "HDD=true\nHDD_MOUNT=%s\n" "$DETECTED_HDD_MOUNT"
    else
        printf "HDD=false\n"
    fi
} >> "$MOJO_CONFIG"

printf "\n# --- System (set at install time, do not edit) ---\nSYSTEM_USER=%s\n" "$SYSTEM_USER" >> "$MOJO_CONFIG"

success ".mojo_config synced"

# =============================================================================
# SECTION 9 — SYSTEM CONFIGURATION
# Applies idempotent system config from the freshly synced .mojo_config.
# Only makes changes if something has drifted from the desired state.
# =============================================================================
section "Applying system configuration"
sudo bash "$FORK_DIR/configure.sh" "$HOME/.mojo_config"
success "System configuration up to date"

# =============================================================================
# DONE
# =============================================================================
section "Upgrade complete"
success "MojOS is up to date"
