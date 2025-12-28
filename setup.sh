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
read -p "Enter your Catbox user-hash: " CATBOX_HASH

# Profile selection
PROFILE_CHOICE="full-desktop"
#echo -e "${CYAN}🖥️ Select your profile (for Dotter deployment):${NC}"
#echo "1) full-desktop (GUI, themes, apps)"
#echo "2) minimal (essentials only)"
#echo "3) laptop (desktop + power tweaks)"
#echo "4) server (headless, system-focused)"
#read -p "Choice (1-4, default 1): " PROFILE_CHOICE
#case $PROFILE_CHOICE in
    #1) PROFILE="full-desktop" ;;
    #2) PROFILE="minimal" ;;
    #3) PROFILE="laptop" ;;
    #4) PROFILE="server" ;;
    #*) PROFILE="full-desktop" ;;  # Default
#esac
echo -e "${GREEN}✅ Selected profile: $PROFILE${NC}"

# --- 1. Generate local.toml ---
echo -e "${CYAN}📝 Generating .dotter/local.toml...${NC}"
mkdir -p .dotter
cat <<EOF > .dotter/local.toml
# Your shared variables (apply to all profiles)
[variables]
username = "$USER_NAME"
email = "$USER_EMAIL"
catbox_hash = "$CATBOX_HASH"

# Active profile
packages = ["$PROFILE"]

# Example overrides (uncomment/customize as needed)
#[$PROFILE.variables]
#primary_theme = "dark"
#font_size = 12
EOF

# --- 1.5 Generate local-root.toml (always root-system for system tweaks) ---
echo -e "${CYAN}📝 Generating .dotter/local-root.toml...${NC}"
cat <<EOF > .dotter/local-root.toml
# Shared variables
[variables]
username = "$USER_NAME"
email = "$USER_EMAIL"
catbox_hash = "$CATBOX_HASH"

# Root profile (system-wide)
packages = ["root-system"]
EOF

# --- 2. System Update & Base Dependencies ---
echo -e "${CYAN}📦 Updating system & installing base deps...${NC}"
sudo pacman -Syu --noconfirm || { echo -e "${RED}❌ System update failed. Check logs.${NC}"; exit 1; }
sudo pacman -S --needed --noconfirm base-devel git neovim zsh curl ripgrep fd unzip tar wget || { echo -e "${RED}❌ Base deps install failed.${NC}"; exit 1; }

# --- 3. Pull Media from Catbox ---
LINKS_FILE=".dotter/catbox_links.txt"
FILES_DIR="./files/Pictures"
mkdir -p "$FILES_DIR"
if [ ! -f "$LINKS_FILE" ]; then
    echo -e "${YELLOW}⚠️ $LINKS_FILE not found, skipping Catbox pulls.${NC}"
else
    pull_package() {
        local folder_name=$1
        echo -e "${CYAN}🔍 Looking for ${folder_name} link...${NC}"
        local link=$(grep "^${folder_name}:" "$LINKS_FILE" | awk '{print $2}' | head -n1)  # Take first match
        if [ -n "$link" ]; then
            echo -e "${CYAN}📥 Downloading $folder_name from $link...${NC}"
            if curl -L -f "$link" | tar -xzf - -C "$FILES_DIR" 2>/dev/null; then
                echo -e "${GREEN}✅ $folder_name restored to $FILES_DIR/${NC}"
            else
                echo -e "${RED}❌ Failed to download/extract $folder_name${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️ No link for '$folder_name'${NC}"
        fi
    }
    pull_package "wallpapers"
    pull_package "grub_backgrounds"
    pull_package "sddm_backgrounds"
    pull_package "pfps"
fi

# --- 4. Install yay (AUR Helper) ---
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
    echo -e "${CYAN}📦 Installing from pkglist.txt...${NC}"
    if yay -S --needed --noconfirm < pkglist.txt; then
        echo -e "${GREEN}✅ Bulk install complete.${NC}"
    else
        echo -e "${YELLOW}⚠️ Bulk install had issues (some packages may have failed).${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ pkglist.txt missing, skipping bulk install.${NC}"
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
    if ./dotter --local-config .dotter/local.toml deploy; then
        echo -e "${GREEN}✅ User deployment complete.${NC}"
    else
        echo -e "${RED}❌ User deployment failed.${NC}"; exit 1;
    fi
    # Dry-run root
    if ! sudo ./dotter --sudo --local-config .dotter/local-root.toml --dry-run deploy; then
        echo -e "${YELLOW}⚠️ Root dry-run had warnings.${NC}"
    fi
    # Deploy root
    if sudo ./dotter --sudo --local-config .dotter/local-root.toml deploy; then
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
