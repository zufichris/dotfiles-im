#!/usr/bin/env bash
#
# Install Hyprland, zellij, fonts, and deploy the config.
#
# Usage: ./install.sh
#

set -euo pipefail

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

readonly REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_SRC="${REPO_DIR}/.config/hypr"
readonly CONFIG_DST="${HOME}/.config/hypr"
readonly SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"

# ---------------------------------------------------------------------------
# Packages
# ---------------------------------------------------------------------------

readonly PACKAGES=(
    hyprland
    ghostty
    zellij
    dolphin
    pipewire
    pipewire-pulse
    wireplumber
    qt5-wayland
    qt6-wayland
)

readonly FONTS=(
    noto-fonts
    noto-fonts-emoji
    ttf-fira-code
    ttf-nerd-fonts-symbols
    ttf-nerd-fonts-symbols-mono
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log()   { echo -e "\033[0;32m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
note()  { echo -e "\033[0;34m[NOTE]\033[0m  $*"; }

confirm() {
    local prompt="$1"
    local answer
    read -rp "${prompt} [Y/n] " answer
    [[ -z "${answer}" || "${answer,,}" == "y" ]]
}

# ---------------------------------------------------------------------------
# Installation
# ---------------------------------------------------------------------------

install_packages() {
    if ! command -v pacman &>/dev/null; then
        warn "pacman not found. Install the equivalent packages manually."
        return
    fi

    if ! command -v sudo &>/dev/null; then
        error "sudo is required for package installation."
        exit 1
    fi

    if pacman -Q pipewire-media-session &>/dev/null; then
        warn "Removing pipewire-media-session (replaced by wireplumber)"
        sudo pacman -Rns --noconfirm pipewire-media-session
    fi

    log "Installing packages: ${PACKAGES[*]}"
    sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"

    log "Enabling PipeWire and WirePlumber user services"
    systemctl --user enable pipewire.service pipewire-pulse.service wireplumber.service || \
        warn "Could not enable audio services. Enable them manually after logging in."
}

install_fonts() {
    if ! command -v pacman &>/dev/null; then
        warn "pacman not found. Install the equivalent fonts manually."
        return
    fi

    if ! command -v sudo &>/dev/null; then
        error "sudo is required for font installation."
        exit 1
    fi

    log "Installing fonts: ${FONTS[*]}"
    sudo pacman -S --needed --noconfirm "${FONTS[@]}"
}

# ---------------------------------------------------------------------------
# Config deployment
# ---------------------------------------------------------------------------

deploy_config() {
    if [[ -e "${CONFIG_DST}" && ! -d "${CONFIG_DST}" ]]; then
        error "${CONFIG_DST} exists and is not a directory"
        exit 1
    fi

    if [[ -d "${CONFIG_DST}" ]]; then
        local backup="${CONFIG_DST}.backup.$(date +%Y%m%d%H%M%S)"
        log "Backing up existing config to ${backup}"
        cp -a "${CONFIG_DST}" "${backup}"
    fi

    log "Deploying config to ${CONFIG_DST}"
    mkdir -p "${CONFIG_DST}"
    cp -v "${CONFIG_SRC}/hyprland.lua" "${CONFIG_DST}/"
    cp -v "${CONFIG_SRC}/screenShader.frag" "${CONFIG_DST}/"

    if [[ -d "${CONFIG_SRC}/layouts" ]]; then
        cp -vr "${CONFIG_SRC}/layouts" "${CONFIG_DST}/"
    fi
}

# ---------------------------------------------------------------------------
# Optional systemd user services
# ---------------------------------------------------------------------------

install_services() {
    [[ -f "${CONFIG_SRC}/hyprland.service" || -f "${CONFIG_SRC}/swaybg@.service" ]] || return

    log "Installing systemd user services"
    mkdir -p "${SYSTEMD_USER_DIR}"

    [[ -f "${CONFIG_SRC}/hyprland.service" ]] && cp -v "${CONFIG_SRC}/hyprland.service" "${SYSTEMD_USER_DIR}/"
    [[ -f "${CONFIG_SRC}/swaybg@.service" ]] && cp -v "${CONFIG_SRC}/swaybg@.service" "${SYSTEMD_USER_DIR}/"

    note "Enable with: systemctl --user enable hyprland.service"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    if [[ ! -d "${CONFIG_SRC}" ]]; then
        error "Config source not found: ${CONFIG_SRC}"
        exit 1
    fi

    log "Packages: ${PACKAGES[*]}"
    log "Fonts: ${FONTS[*]}"

    if confirm "Install packages?"; then
        install_packages
    fi

    if confirm "Install fonts?"; then
        install_fonts
    fi

    deploy_config

    if confirm "Install systemd user services?"; then
        install_services
    fi

    log "Done."
    note "Start Hyprland with: Hyprland"
}

main "$@"
