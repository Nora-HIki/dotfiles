#!/bin/bash
set -e # Exit immediately if a command fails

# Colors for feedback
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}🎨 Configuration Wizard${NC}"

# User inputs
read -p "Enter your full name: " USER_NAME
read -p "Enter your git email: " USER_EMAIL

# --- 1. Generate local.toml ---
echo -e "${CYAN}📝 Generating .dotter/local.toml...${NC}"
mkdir -p .dotter
cat <<EOF > .dotter/local.toml
packages = ["terminal", "themes", "desktop", "apps", "gui_libs", "system_user"]

[variables]
username = "$USER_NAME"
email = "$USER_EMAIL"
EOF

# --- 1.5 Generate local-root.toml (always root-system for system tweaks) ---
echo -e "${CYAN}📝 Generating .dotter/local-root.toml...${NC}"
cat <<EOF > .dotter/local-root.toml
packages = ["grub", "sddm", "plymouth", "systemd"]

[variables]
username = "$USER_NAME"
email = "$USER_EMAIL"
EOF

# --- 2. System Update & Base Dependencies ---
echo -e "${CYAN}📦 Updating system & installing base deps...${NC}"
sudo pacman -Syu --noconfirm || { echo -e "${RED}❌ System update failed. Check logs.${NC}"; exit 1; }
sudo pacman -S --needed --noconfirm base-devel git neovim zsh curl ripgrep fd unzip tar wget || { echo -e "${RED}❌ Base deps install failed.${NC}"; exit 1; }

# # --- 4. Install yay (AUR Helper) ---
if ! command -v yay &> /dev/null; then
    echo -e "${CYAN}🏗️ Building yay...${NC}"
    CLONE_DIR=$(mktemp -d)
    if git clone https://aur.archlinux.org/yay.git "$CLONE_DIR" 2>/dev/null; then
        cd "$CLONE_DIR"
        if makepkg -si --noconfirm; then
            echo -e "${GREEN}✅ yay installed.${NC}"
        else
            echo -e "${RED}❌ yay build failed.${NC}"; exit 1;
        fi
        cd - > /dev/null
        rm -rf "$CLONE_DIR"
    else
        echo -e "${RED}❌ Failed to clone yay.${NC}"; exit 1;
    fi
else
    echo -e "${GREEN}⏩ yay already installed.${NC}"
fi


# --- 4.5 Bulk Package Installation (Unattended) ---
if [ -f "pkglist.txt" ]; then
    echo -e "📦 Installing from pkglist.txt (one by one, skipping failures)..."
    while read -r pkg; do
        [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue # Skip empty lines or comments
        yay -S --needed --noconfirm "$pkg" || echo -e " ${YELLOW}⚠️ Failed: $pkg ${NC}"
    done < pkglist.txt
    echo -e "${GREEN}✅ Bulk install attempt complete. ${NC}"
else
    echo -e "${YELLOW}⚠️ pkglist.txt missing, skipping bulk install. ${NC}"
fi
# --- 5. Install Oh My Zsh (Unattended) ---
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo -e "${CYAN}🐚 Installing Oh My Zsh...${NC}"
    if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
        if sudo chsh -s "$(which zsh)" "$(logname)" 2>/dev/null; then
            echo -e "${GREEN}✅ Oh My Zsh & zsh shell set.${NC}"
        else
            echo -e "${YELLOW}⚠️ Oh My Zsh installed, but chsh failed (manual: chsh -s zsh).${NC}"
        fi
    else
        echo -e "${RED}❌ Oh My Zsh install failed.${NC}"; exit 1;
    fi
else
    echo -e "${GREEN}⏩ Oh My Zsh already installed.${NC}"
fi

# --- 6. Install NvChad Starter ---
if [ ! -d "$HOME/.config/nvim" ] || [ -z "$(ls -A $HOME/.config/nvim 2>/dev/null)" ]; then
    echo -e "${CYAN}⚡ Installing NvChad Starter...${NC}"
    rm -rf "$HOME/.config/nvim"  # Clean if empty dir
    if git clone https://github.com/NvChad/starter ~/.config/nvim; then
        echo -e "${GREEN}✅ NvChad installed.${NC}"
    else
        echo -e "${RED}❌ NvChad clone failed.${NC}"; exit 1;
    fi
else
    echo -e "${GREEN}⏩ Neovim config exists (skipping NvChad).${NC}"
fi

# --- 7. Install Nerd Fonts (JetBrainsMono) ---
if ! fc-list | grep -qi "JetBrainsMono"; then
    echo -e "${CYAN}🔡 Installing JetBrainsMono Nerd Font...${NC}"
    if yay -S --noconfirm ttf-jetbrains-mono-nerd; then
        fc-cache -fv
        echo -e "${GREEN}✅ Nerd Font installed & cached.${NC}"
    else
        echo -e "${RED}❌ Nerd Font install failed.${NC}"
    fi
else
    echo -e "${GREEN}⏩ JetBrainsMono Nerd Font already available.${NC}"
fi

# --- 8. Backup Existing Dotfiles (Safety Net) ---
echo -e "${CYAN}💾 Backing up existing dotfiles...${NC}"
BACKUP_DIR="$HOME/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
for dir in .config .zshrc .zprofile .gitconfig; do
    if [ -e "$HOME/$dir" ]; then
        cp -r "$HOME/$dir" "$BACKUP_DIR/" 2>/dev/null || true
        echo -e "${GREEN}✅ Backed up ~/$dir${NC}"
    fi
done
echo -e "${YELLOW}📂 Backup saved to $BACKUP_DIR${NC}"

# --- 9. Run Dotter Deployment ---
echo -e "${CYAN}🚀 Deploying with Dotter (dry-run first)...${NC}"
if [ -f "./dotter" ]; then
    # Dry-run user
    if ! ./dotter --local-config .dotter/local.toml --dry-run deploy; then
        echo -e "${YELLOW}⚠️ Dry-run had warnings, but proceeding.${NC}"
    fi
    # Deploy user
    if ./dotter --local-config .dotter/local.toml deploy --force; then
        echo -e "${GREEN}✅ User deployment complete.${NC}"
    else
        echo -e "${RED}❌ User deployment failed.${NC}"; exit 1;
    fi
    # Dry-run root
    if ! sudo ./dotter --sudo --local-config .dotter/local-root.toml --dry-run deploy; then
        echo -e "${YELLOW}⚠️ Root dry-run had warnings.${NC}"
    fi
    # Deploy root
    if sudo ./dotter --sudo --local-config .dotter/local-root.toml deploy --force; then
        echo -e "${GREEN}✅ Root deployment complete.${NC}"
    else
        echo -e "${RED}❌ Root deployment failed.${NC}"
    fi
else
    echo -e "${RED}❌ dotter binary not found! Download from GitHub releases.${NC}"; exit 1;
fi

echo -e "${GREEN}🎉 Installation & Rice Deployment Complete!${NC}"
echo -e "${YELLOW}💡 To switch profiles later: Edit .dotter/local.toml (packages array) & run 'dotter deploy'.${NC}"
echo -e "${YELLOW}💡 Restore backup if needed: cp -r $BACKUP_DIR/* ~/${NC}"
echo -e "${CYAN}🔄 Log out/in for full effect (e.g., zsh, themes).${NC}"
