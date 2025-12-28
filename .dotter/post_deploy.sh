#!/bin/bash
set -e  # Exit immediately if a command fails

# Colors for feedback
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 1. --- USER IDENTIFICATION ---
USER_NAME=$(logname 2>/dev/null || whoami)
if [[ -z "$USER_NAME" || "$USER_NAME" == "root" ]]; then
    echo -e "${RED}❌ This script must run as a non-root user or with sudo -u <user>.${NC}"
    exit 1
fi
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
if [[ -z "$USER_HOME" ]]; then
    USER_HOME="$HOME"
fi
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo -e "${CYAN}🚀 Starting post-deployment for $USER_NAME...${NC}"

# 2. --- ICON EXTRACTION ---
ICON_DIR="$USER_HOME/.icons"
if [ -d "$ICON_DIR" ]; then
    echo -e "${CYAN}📦 Checking for icon archives...${NC}"
    cd "$ICON_DIR" || { echo -e "${RED}❌ Failed to cd to $ICON_DIR${NC}"; exit 1; }
    for archive in *.tar.xz; do
        [ -e "$archive" ] || continue
        FOLDER_NAME="${archive%.tar.xz}"
        if [ -d "$FOLDER_NAME" ]; then
            echo -e "${YELLOW}⏩ $FOLDER_NAME already extracted, removing archive.${NC}"
            rm -f "$archive"
        else
            echo -e "${CYAN}📂 Extracting $archive...${NC}"
            if tar -xf "$archive"; then
                rm -f "$archive"
                echo -e "${GREEN}✅ $archive extracted.${NC}"
            else
                echo -e "${RED}❌ Extraction failed for $archive${NC}"
            fi
        fi
    done
else
    echo -e "${YELLOW}⚠️ $ICON_DIR not found, skipping icon extraction.${NC}"
fi

# 3. --- SYSTEM PERMISSIONS & GRUB ---
echo -e "${CYAN}⚙️ Fixing system permissions and GRUB...${NC}"

# Backup modified files
backup_file() {
    local file="$1"
    if [ -f "$file" ] && [ ! -f "$file.bak" ]; then
        sudo cp "$file" "$file.bak"
        echo -e "${GREEN}💾 Backed up $file${NC}"
    fi
}

# SDDM Permissions
if [ -d "/usr/share/sddm/themes/silent" ]; then
    echo -e "${CYAN}🔒 Setting SDDM permissions...${NC}"
    sudo chown -R "$USER_NAME":"$USER_NAME" /usr/share/sddm/themes/silent/backgrounds 2>/dev/null || true
    sudo chmod -R 755 /usr/share/sddm/themes/silent 2>/dev/null || true
    echo -e "${GREEN}✅ SDDM permissions set.${NC}"
else
    echo -e "${YELLOW}⚠️ SDDM theme dir not found.${NC}"
fi
sudo cp -r $USER_HOME/dotfiles/files/sddm/silent /usr/share/sddm/themes/
# GRUB Patches (safer sed with backup)
GRUB_HEADER="/etc/grub.d/00_header"
GRUB_DEFAULT="/etc/default/grub"
backup_file "$GRUB_HEADER"
backup_file "$GRUB_DEFAULT"

if [ -f "$GRUB_HEADER" ]; then
    echo -e "${CYAN}🛠️ Patching GRUB header...${NC}"
    if sudo sed -i.bak -E 's/(.*)elif(.*"x\$GRUB_BACKGROUND" != x ] && [ -f "\$GRUB_BACKGROUND" ].*)/\1fi; if\2/' "$GRUB_HEADER"; then
        echo -e "${GREEN}✅ GRUB header patched.${NC}"
    else
        echo -e "${RED}❌ GRUB header patch failed.${NC}"
    fi
fi

if [ -f "$GRUB_DEFAULT" ]; then
    echo -e "${CYAN}🎨 Setting GRUB theme/background...${NC}"
    sudo sed -i 's|^[#]*GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/grubsouls/theme.txt"|' "$GRUB_DEFAULT"
    sudo sed -i 's|^[#]*GRUB_BACKGROUND=.*|GRUB_BACKGROUND="/boot/grub/themes/grubsouls/terminal_background.png"|' "$GRUB_DEFAULT"
    if ! grep -q "quiet splash loglevel=3" "$GRUB_DEFAULT"; then
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 /' "$GRUB_DEFAULT"
    fi
    echo -e "${GREEN}✅ GRUB config updated.${NC}"
fi

# Sync GRUB backgrounds
echo -e "${CYAN}🖼️ Syncing GRUB backgrounds...${NC}"
sudo mkdir -p /boot/grub/themes/grubsouls/backgrounds
if [ -d "/home/$USER_NAME/Pictures/grub_backgrounds" ]; then
    sudo cp "/home/$USER_NAME/Pictures/grub_backgrounds"/* /boot/grub/themes/grubsouls/backgrounds/ 2>/dev/null || true
    echo -e "${GREEN}✅ GRUB backgrounds synced.${NC}"
else
    echo -e "${YELLOW}⚠️ GRUB backgrounds dir not found.${NC}"
fi

# 4. --- SERVICES & REGEN ---
echo -e "${CYAN}🔄 Reloading services...${NC}"
sudo systemctl daemon-reload
# Enable services quietly, ignore failures for non-existent ones
services=("NetworkManager" "bluetooth" "sddm" "grubsouls-update.service" "sddm-wallpaper-update.service")
for svc in "${services[@]}"; do
    sudo systemctl enable --now "$svc" >/dev/null 2>&1 || echo -e "${YELLOW}⚠️ Service $svc enable failed (may not exist).${NC}"
done
echo -e "${GREEN}✅ Services managed.${NC}"

# 5. --- GRUB REGENERATION ---
if command -v update-grub &> /dev/null; then
    echo -e "${CYAN}🔄 Updating GRUB...${NC}"
    if sudo update-grub; then
        echo -e "${GREEN}✅ GRUB updated.${NC}"
    else
        echo -e "${RED}❌ GRUB update failed.${NC}"; exit 1;
    fi
elif command -v grub-mkconfig &> /dev/null; then
    echo -e "${CYAN}🔄 Generating GRUB config...${NC}"
    if sudo grub-mkconfig -o /boot/grub/grub.cfg; then
        echo -e "${GREEN}✅ GRUB config generated.${NC}"
    else
        echo -e "${RED}❌ GRUB config generation failed.${NC}"; exit 1;
    fi
else
    echo -e "${YELLOW}⚠️ No GRUB tools found.${NC}"
fi

# 6. --- INTERACTIVE FIREFOX & TEXTFOX ---
echo -e "\n${YELLOW}🦊 STEP 1: Firefox Profile Setup${NC}"
echo "--------------------------------------------------"
echo "1. We'll open Firefox to about:profiles."
echo "2. Find 'Root Directory' in your desired profile (e.g., /home/$USER_NAME/.mozilla/firefox/xxxx.default-release)."
echo "3. COPY that path."
echo "4. Paste it below when prompted."
echo "--------------------------------------------------"
echo -e "${CYAN}🦊 Launching Firefox...${NC}"
# Launch Firefox as the user in background
sudo -u "$USER_NAME" firefox about:profiles >/dev/null 2>&1 &
FF_PID=$!
sleep 3  # Give time to load

echo "Waiting for path input (Firefox should be open)..."
read -p "Paste the Root Directory path here (or Enter to skip Textfox): " MANUAL_PATH
kill $FF_PID 2>/dev/null || true  # Clean up Firefox if still running

TEXTFOX_DIR="$USER_HOME/textfox"
TEXTFOX_INSTALLER="$TEXTFOX_DIR/tf-install.sh"

if [ -f "$TEXTFOX_INSTALLER" ]; then
    echo -e "${CYAN}🔧 Running Textfox installer...${NC}"
    chmod +x "$TEXTFOX_INSTALLER"
    
    # Change directory to where the files actually are before running
    # We use ( ) to run in a subshell so we don't change the path for the rest of your script
    (
        cd "$TEXTFOX_DIR" || exit
        if sudo -u "$USER_NAME" bash "./tf-install.sh" "$MANUAL_PATH"; then
            echo -e "${GREEN}✅ Textfox installed.${NC}"
        else
            echo -e "${YELLOW}⚠️ Textfox install completed with issues.${NC}"
        fi
    )
else
    echo -e "${YELLOW}⚠️ Textfox installer not found at $TEXTFOX_INSTALLER.${NC}"
fi

# 7. --- TIMESHIFT ---
if command -v timeshift-launcher &> /dev/null; then
    echo -e "\n${YELLOW}🛡️ STEP 2: Timeshift Setup${NC}"
    echo "Launching Timeshift for backup configuration..."
    sudo timeshift-launcher >/dev/null 2>&1 &
    echo -e "${CYAN}📅 Timeshift opened—configure your first snapshot.${NC}"
else
    echo -e "${YELLOW}⚠️ timeshift-launcher not found; install Timeshift for backups.${NC}"
fi

echo -e "\n${GREEN}🎉 Post-deployment complete!${NC}"
echo -e "${YELLOW}💡 Reboot recommended for GRUB/SDDM changes.${NC}"
echo -e "${YELLOW}💡 Check backups: /etc/grub.d/00_header.bak, /etc/default/grub.bak${NC}"
exit 0
