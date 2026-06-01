#!/usr/bin/env bash

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


install_prerequisites() {
    echo "==> Installing prerequisites"

    sudo pacman -Sy --needed --noconfirm \
        git \
        curl \
        base-devel \
        zsh
}

install_paru() {
    if command -v paru >/dev/null 2>&1; then
        return
    fi

    echo "==> Installing paru"

    mkdir -p "$HOME/tmp"

    TMP_DIR=$(mktemp -d -p "$HOME/tmp")

    (
        cd "$TMP_DIR/paru"
        makepkg -si --noconfirm
    )

    rm -rf "$TMP_DIR"
}

echo "==> Installing packages"

install_prerequisites
install_paru


echo "==> Creating directories"

mkdir -p ~/Code
mkdir -p ~/Personal
mkdir -p ~/servers
mkdir -p ~/tmp

mkdir -p ~/.config
mkdir -p ~/.local/bin
mkdir -p ~/.tmux/plugins

echo "==> Installing Oh My Zsh"

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

echo "==> Installing Powerlevel10k"

if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
    git clone \
        https://github.com/romkatv/powerlevel10k.git \
        "$ZSH_CUSTOM/themes/powerlevel10k"
fi

echo "==> Installing zsh plugins"

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone \
        https://github.com/zsh-users/zsh-autosuggestions \
        "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone \
        https://github.com/zsh-users/zsh-syntax-highlighting \
        "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

echo "==> Installing TPM"

if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    git clone \
        https://github.com/tmux-plugins/tpm \
        "$HOME/.tmux/plugins/tpm"
fi

echo "==> Linking config files"

for dir in "$DOTFILES_DIR/.config"/*; do
    name=$(basename "$dir")
    ln -sfn "$dir" "$HOME/.config/$name"
done

echo "==> Linking local bin scripts"

for file in "$DOTFILES_DIR/.local/bin"/*; do
    name=$(basename "$file")
    ln -sfn "$file" "$HOME/.local/bin/$name"
    chmod +x "$HOME/.local/bin/$name"
done

echo "==> Linking home files"

ln -sfn "$DOTFILES_DIR/home/.zshrc" "$HOME/.zshrc"
ln -sfn "$DOTFILES_DIR/home/.p10k.zsh" "$HOME/.p10k.zsh"
ln -sfn "$DOTFILES_DIR/home/.gitconfig" "$HOME/.gitconfig"
ln -sfn "$DOTFILES_DIR/home/.tmux.conf" "$HOME/.tmux.conf"

echo "==> Restoring tmux plugins"

if command -v tmux >/dev/null 2>&1; then
    "$HOME/.tmux/plugins/tpm/bin/install_plugins" || true
fi

echo "==> Setting zsh as default shell"

if command -v zsh >/dev/null 2>&1; then
    chsh -s "$(which zsh)" "$USER" || true
fi

echo
echo "Installation complete."
echo "Log out and back in to start using zsh."
