#!/bin/bash
set -e # Exit immediately if a command fails

# Colors for feedback
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}🎨 Configuration Wizard${NC}"
read -p "Enter your full name: " USER_NAME
read -p "Enter your git email: " USER_EMAIL
read -p "Enter your Catbox user-hash: " CATBOX_HASH

# --- 1. Generate local.toml ---
echo -e "${CYAN}📝 Generating .dotter/local.toml...${NC}"
mkdir -p .dotter
cat <<EOF > .dotter/local.toml
packages = [
    "terminal", "themes", "desktop", "apps", 
    "gui_libs", "system_user", "grub", "sddm", 
    "plymouth", "systemd", "Pictures"
]

[variables]
username = "$USER_NAME"
email = "$USER_EMAIL"
catbox_hash = "$CATBOX_HASH"
EOF

# --- 2. System Update & Base Dependencies ---
echo -e "${CYAN}📦 Installing base dependencies...${NC}"
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm base-devel git neovim zsh curl ripgrep fd unzip tar wget

# --- 3. Pull Media from Catbox ---
LINKS_FILE=".dotter/catbox_links.txt"
FILES_DIR="./files/Pictures"
mkdir -p "$FILES_DIR"

pull_package() {
    local folder_name=$1
    if [ ! -f "$LINKS_FILE" ]; then
        echo -e "${YELLOW}⚠️ $LINKS_FILE not found, skipping $folder_name pull.${NC}"
        return
    fi

    echo -e "${CYAN}🔍 Looking for ${folder_name} link...${NC}"
    local link=$(grep "^${folder_name}:" "$LINKS_FILE" | awk '{print $2}')

    if [ -n "$link" ]; then
        echo -e "${CYAN}📥 Downloading $folder_name from $link...${NC}"
        curl -L "$link" | tar -xzf - -C "$FILES_DIR"
        echo -e "${GREEN}✅ $folder_name restored to $FILES_DIR.${NC}"
    else
        echo -e "${YELLOW}⚠️ No link found for '$folder_name' in $LINKS_FILE${NC}"
    fi
}

pull_package "wallpapers"
pull_package "grub_backgrounds"
pull_package "sddm_backgrounds"
pull_package "pfps"

# --- 4. Install yay (AUR Helper) ---
if ! command -v yay &> /dev/null; then
    echo -e "${CYAN}🏗️ Building yay...${NC}"
    CLONE_DIR=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$CLONE_DIR"
    cd "$CLONE_DIR"
    makepkg -si --noconfirm
    cd -
else
    echo -e "${GREEN}⏩ yay is already installed.${NC}"
fi

# --- 4.5 Bulk Package Installation (Unattended) ---
if [ -f "pkglist.txt" ]; then
    echo -e "${CYAN}📦 Installing packages from pkglist.txt...${NC}"
    # --needed: don't reinstall up-to-date packages
    # --noconfirm: unattended mode
    yay -S --needed --noconfirm - < pkglist.txt
    echo -e "${GREEN}✅ Bulk installation complete.${NC}"
else
    echo -e "${YELLOW}⚠️ pkglist.txt not found, skipping bulk installation.${NC}"
fi

# --- 5. Install Oh My Zsh (Unattended) ---
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo -e "${CYAN}🐚 Installing Oh My Zsh...${NC}"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    sudo chsh -s "$(which zsh)" "$(logname)"
else
    echo -e "${GREEN}⏩ Oh My Zsh is already installed.${NC}"
fi

# --- 6. Install NvChad ---
if [ ! -d "$HOME/.config/nvim" ]; then
    echo -e "${CYAN}⚡ Installing NvChad Starter...${NC}"
    git clone https://github.com/NvChad/starter ~/.config/nvim
else
    echo -e "${GREEN}⏩ Neovim config already exists.${NC}"
fi

# --- 7. Install Nerd Fonts ---
if ! fc-list | grep -qi "JetBrainsMono"; then
    echo -e "${CYAN}🔡 Installing JetBrainsMono Nerd Font...${NC}"
    yay -S --noconfirm ttf-jetbrains-mono-nerd
    fc-cache -fv
fi

# --- 8. Run Dotter Deployment ---
echo -e "${CYAN}🚀 Running Dotter Deployment...${NC}"
if [ -f "./dotter" ]; then
    sudo -E ./dotter deploy
else
    echo -e "${YELLOW}⚠️ Dotter binary not found in root! Trying system dotter...${NC}"
    sudo -E dotter deploy
fi

echo -e "${GREEN}🎉 Installation and Rice Deployment Complete!${NC}"
