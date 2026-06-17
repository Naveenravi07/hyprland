#!/usr/bin/env bash
# =============================================================================
#  dotfiles/install.sh — Hyprland rice installer
#  Usage: ./install.sh [--dry-run]
# =============================================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
DRY_RUN=false

# ── parse flags ──────────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) echo "Unknown flag: $arg"; exit 1 ;;
  esac
done

# ── colors ───────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; RESET=''
fi

info()    { echo -e "${BLUE}==>${RESET} ${BOLD}$*${RESET}"; }
success() { echo -e "${GREEN} ✓${RESET} $*"; }
warn()    { echo -e "${YELLOW} ⚠${RESET} $*"; }
error()   { echo -e "${RED} ✗${RESET} $*" >&2; }
run()     { $DRY_RUN && echo -e "${YELLOW}[dry-run]${RESET} $*" || "$@"; }

# ── error trap ───────────────────────────────────────────────────────────────
trap 'error "Script failed at line $LINENO. Exit code: $?"' ERR

# ── swap check / setup ───────────────────────────────────────────────────────
ensure_swap() {
  if swapon --show | grep -q .; then
    success "Swap already active"
    return
  fi
  warn "No swap detected — setting up 4G swapfile to prevent OOM during Rust compilation"
  if ! $DRY_RUN; then
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    # make it permanent
    grep -q '/swapfile' /etc/fstab \
      || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  fi
  success "Swap ready"
}

# ── prerequisites ─────────────────────────────────────────────────────────────
install_prerequisites() {
  info "Installing prerequisites"
  run sudo pacman -Sy --needed --noconfirm \
    git curl base-devel zsh rustup
  success "Prerequisites installed"
}

# ── paru ─────────────────────────────────────────────────────────────────────
install_paru() {
  if command -v paru &>/dev/null; then
    success "paru already installed — skipping"
    return
  fi

  info "Installing paru"
  mkdir -p "$HOME/tmp"                          
  local tmp_dir
  tmp_dir=$(mktemp -d -p "$HOME/tmp")

  git clone --depth=1 https://aur.archlinux.org/paru.git "$tmp_dir/paru"

  (
    cd "$tmp_dir/paru"
    # -j2 prevents OOM on low-RAM machines during rustc compilation
    MAKEFLAGS="-j2" run makepkg -si --noconfirm
  )

  rm -rf "$tmp_dir"

  if command -v paru &>/dev/null; then
    success "paru installed"
  else
    error "paru installation failed"
    return 1
  fi
}

# ── AUR packages ──────────────────────────────────────────────────────────────
install_packages() {
  if ! command -v paru &>/dev/null; then
    warn "paru not found — skipping package installation"
    return
  fi

  local pkg_file="$DOTFILES_DIR/packages.txt"
  if [[ ! -f "$pkg_file" ]]; then
    warn "packages.txt not found — skipping"
    return
  fi

  info "Installing packages from packages.txt"
  run paru -S --needed --noconfirm - < "$pkg_file"
  success "Packages installed"
}

# ── directories ───────────────────────────────────────────────────────────────
create_dirs() {
  info "Creating directories"
  local dirs=(
    ~/Code ~/Personal ~/servers ~/tmp
    ~/.config ~/.local/bin ~/.tmux/plugins
  )
  for d in "${dirs[@]}"; do
    run mkdir -p "$d"
  done
  success "Directories ready"
}

# ── oh-my-zsh ────────────────────────────────────────────────────────────────
install_omz() {
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    success "Oh My Zsh already installed — skipping"
    return
  fi
  info "Installing Oh My Zsh"
  run env RUNZSH=no CHSH=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  success "Oh My Zsh installed"
}

# ── zsh plugins + theme ───────────────────────────────────────────────────────
install_zsh_extras() {
  local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

  info "Installing Powerlevel10k"
  if [[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
    run git clone --depth=1 \
      https://github.com/romkatv/powerlevel10k.git \
      "$ZSH_CUSTOM/themes/powerlevel10k"
  else
    success "Powerlevel10k already installed — skipping"
  fi

  info "Installing zsh-autosuggestions"
  if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    run git clone --depth=1 \
      https://github.com/zsh-users/zsh-autosuggestions \
      "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  else
    success "zsh-autosuggestions already installed — skipping"
  fi

  info "Installing zsh-syntax-highlighting"
  if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    run git clone --depth=1 \
      https://github.com/zsh-users/zsh-syntax-highlighting \
      "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  else
    success "zsh-syntax-highlighting already installed — skipping"
  fi
}

# ── TPM ──────────────────────────────────────────────────────────────────────
install_tpm() {
  info "Installing TPM"
  if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
    run git clone --depth=1 \
      https://github.com/tmux-plugins/tpm \
      "$HOME/.tmux/plugins/tpm"
    success "TPM installed"
  else
    success "TPM already installed — skipping"
  fi
}

# ── symlinks (with backup) ────────────────────────────────────────────────────
safe_link() {
  local src="$1" dst="$2"

  # back up only if it's a real file/dir (not already a symlink to us)
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    run mkdir -p "$BACKUP_DIR"
    run mv "$dst" "$BACKUP_DIR/"
    warn "Backed up existing $(basename "$dst") → $BACKUP_DIR/"
  fi

  run ln -sfn "$src" "$dst"
}

link_configs() {
  info "Linking .config directories"
  for dir in "$DOTFILES_DIR/.config"/*/; do
    [[ -d "$dir" ]] || continue
    safe_link "$dir" "$HOME/.config/$(basename "$dir")"
  done
  success ".config links done"

  info "Linking .local/bin scripts"
  if [[ -d "$DOTFILES_DIR/.local/bin" ]]; then
    for file in "$DOTFILES_DIR/.local/bin"/*; do
      [[ -f "$file" ]] || continue
      local dst="$HOME/.local/bin/$(basename "$file")"
      safe_link "$file" "$dst"
      run chmod +x "$dst"
    done
    success ".local/bin links done"
  else
    warn ".local/bin directory not found — skipping"
  fi

  info "Linking home dotfiles"
  local home_files=(.zshrc .p10k.zsh .gitconfig .tmux.conf)
  for f in "${home_files[@]}"; do
    local src="$DOTFILES_DIR/home/$f"
    if [[ -f "$src" ]]; then
      safe_link "$src" "$HOME/$f"
    else
      warn "$src not found — skipping"
    fi
  done
  success "Home dotfiles linked"
}

# ── tmux plugins ──────────────────────────────────────────────────────────────
restore_tmux_plugins() {
  info "Restoring tmux plugins"
  if command -v tmux &>/dev/null; then
    run "$HOME/.tmux/plugins/tpm/bin/install_plugins" || warn "TPM plugin install had issues (non-fatal)"
    success "tmux plugins restored"
  else
    warn "tmux not found — skipping plugin restore"
  fi
}

# ── default shell ─────────────────────────────────────────────────────────────
set_zsh_default() {
  info "Setting zsh as default shell"
  if command -v zsh &>/dev/null; then
    local zsh_path
    zsh_path="$(which zsh)"
    if [[ "$SHELL" == "$zsh_path" ]]; then
      success "zsh is already the default shell"
    else
      run chsh -s "$zsh_path" "$USER" || warn "chsh failed (non-fatal — set manually if needed)"
      success "Default shell set to zsh"
    fi
  else
    warn "zsh not found — skipping"
  fi
}

# =============================================================================
#  MAIN
# =============================================================================
$DRY_RUN && warn "DRY-RUN mode — no changes will be made\n"

ensure_swap
install_prerequisites
install_paru
install_packages
create_dirs
install_omz
install_zsh_extras
install_tpm
link_configs
restore_tmux_plugins
set_zsh_default

echo
echo -e "${GREEN}${BOLD}Installation complete.${RESET}"
echo "Log out and back in (or run: exec zsh) to start using zsh."
[[ -d "$BACKUP_DIR" ]] && echo -e "${YELLOW}Backups saved to:${RESET} $BACKUP_DIR"