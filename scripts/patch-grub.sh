#!/bin/bash

# --- PATHS (Updated for Dotdrop) ---
# We use $(logname) to get your username even when running with sudo
USER_NAME=$(logname)
DOTFILES_ROOT="/home/$USER_NAME/The_Dotfiles/dotfiles-root"
# We assume backgrounds are stored in your home dotfiles
BACKGROUNDS_SRC="/home/$USER_NAME/The_Dotfiles/dotfiles/Pictures/grub_backgrounds"

# Colors for feedback
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Applying Grubsouls Rice via Dotdrop...${NC}"

# 1. Backgrounds (Copying from your dotfiles repo to the system theme folder)
# We do this here because backgrounds often change and aren't always 'config' files
echo "Syncing GRUB backgrounds..."
sudo mkdir -p /boot/grub/themes/grubsouls/backgrounds
if [ -d "$BACKGROUNDS_SRC" ]; then
    sudo cp "$BACKGROUNDS_SRC"/* /boot/grub/themes/grubsouls/backgrounds/
fi

# 2. Patch for console background (The '00_header' hack)
# Note: You are also managing this file in dotdrop, but this ensures the hack is applied.
echo "Patching 00_header for console background..."
sudo sed --in-place -E 's/(.*)elif(.*"x\$GRUB_BACKGROUND" != x ] && [ -f "\$GRUB_BACKGROUND" ].*)/\1fi; if\2/' /etc/grub.d/00_header

# 3. Patching /etc/default/grub (PRESERVING YOUR UUIDs)
echo "Patching /etc/default/grub settings..."

# Set Theme
sudo sed -i 's|^[#]*GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/grubsouls/theme.txt"|' /etc/default/grub

# Set Background
sudo sed -i 's|^[#]*GRUB_BACKGROUND=.*|GRUB_BACKGROUND="/boot/grub/themes/grubsouls/terminal_background.png"|' /etc/default/grub

# Set Quiet Splash (This adds it to the existing line without touching UUIDs)
if ! grep -q "quiet splash loglevel=3" /etc/default/grub; then
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 /' /etc/default/grub
fi

# 4. Enable the background update service
# (Dotdrop already copied the file to /etc/systemd/system/)
echo "Enabling background service..."
sudo systemctl daemon-reload
sudo systemctl enable grubsouls-update.service

# 5. Regenerate the GRUB config
echo -e "${YELLOW}Regenerating GRUB menu...${NC}"
if command -v update-grub &> /dev/null; then
    sudo update-grub
else
    sudo grub-mkconfig -o /boot/grub/grub.cfg
fi

echo -e "${GREEN}Grubsouls Rice Deployed Successfully!${NC}"
