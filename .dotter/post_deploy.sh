#!/bin/bash
# Dotter Post-Deploy Hook: Icons + Grubsouls Rice + System Fixes + Interactive Textfox

# 1. --- USER IDENTIFICATION ---
USER_NAME=$(logname)
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🚀 Starting post-deployment for $USER_NAME..."

# 2. --- ICON EXTRACTION ---
ICON_DIR="$USER_HOME/.icons"
if [ -d "$ICON_DIR" ]; then
    echo "📦 Checking for icon archives..."
    cd "$ICON_DIR" || exit
    for archive in *.tar.xz; do
        [ -e "$archive" ] || continue
        FOLDER_NAME="${archive%.tar.xz}"
        if [ -d "$FOLDER_NAME" ]; then
            rm "$archive"
        else
            echo "📂 Extracting $archive..."
            tar -xf "$archive" && rm "$archive"
        fi
    done
fi

# 3. --- SYSTEM PERMISSIONS & GRUB ---
echo "⚙️  Fixing system permissions and GRUB..."
# SDDM
if [ -d "/usr/share/sddm/themes/silent" ]; then
    chown -R "$USER_NAME":"$USER_NAME" /usr/share/sddm/themes/silent/backgrounds
    chmod -R 755 /usr/share/sddm/themes/silent
fi
# GRUB Patches
[ -f "/etc/grub.d/00_header" ] && sed -i -E 's/(.*)elif(.*"x\$GRUB_BACKGROUND" != x ] && [ -f "\$GRUB_BACKGROUND" ].*)/\1fi; if\2/' /etc/grub.d/00_header
if [ -f "/etc/default/grub" ]; then
    sed -i 's|^[#]*GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/grubsouls/theme.txt"|' /etc/default/grub
    sed -i 's|^[#]*GRUB_BACKGROUND=.*|GRUB_BACKGROUND="/boot/grub/themes/grubsouls/terminal_background.png"|' /etc/default/grub
    grep -q "quiet splash loglevel=3" /etc/default/grub || sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 /' /etc/default/grub
fi

# 4. --- SERVICES & REGEN ---
systemctl daemon-reload
systemctl enable --now NetworkManager bluetooth sddm grubsouls-update.service sddm-wallpaper-update.service >/dev/null 2>&1

if command -v update-grub &> /dev/null; then update-grub; else grub-mkconfig -o /boot/grub/grub.cfg; fi

# 5. --- INTERACTIVE FIREFOX & TEXTFOX ---
echo -e "\n\033[0;33m🦊 STEP 1: Opening Firefox about:profiles...\033[0m"
echo "--------------------------------------------------"
echo "1. Look for 'Root Directory' in your desired profile."
echo "2. COPY that path (e.g., /home/$USER_NAME/.mozilla/firefox/xxxx.default-release)."
echo "3. DO NOT close Firefox yet."
echo "--------------------------------------------------"

# Launch Firefox in background so script continues to the prompt
sudo -u "$USER_NAME" DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u $USER_NAME)/bus firefox about:profiles >/dev/null 2>&1 &

# Wait for user input
echo -e "\033[0;32m👉 Once you have copied the path, return here.\033[0m"
read -p "Press [Enter] to run the Textfox Installer..."

TEXTFOX_INSTALLER="$DOTFILES_ROOT/files/textfox/tf-install.sh"
if [ -f "$TEXTFOX_INSTALLER" ]; then
    echo -e "\n\033[0;36m⚡ Running Textfox Installer...\033[0m"
    chmod +x "$TEXTFOX_INSTALLER"
    # Run in foreground so you can paste the path when it asks
    sudo -u "$USER_NAME" bash "$TEXTFOX_INSTALLER"
fi

# 6. --- TIMESHIFT ---
echo -e "\n\033[0;33m🛡️ Opening Timeshift for final backup config...\033[0m"
sudo timeshift-launcher >/dev/null 2>&1 &

echo -e "\n\033[0;32m🎉 Deployment Successful!\033[0m"
exit 0
