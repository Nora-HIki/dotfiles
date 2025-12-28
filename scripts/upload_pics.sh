#!/bin/bash

# --- CONFIGURATION ---
read -p "enter catbox hash" CATBOX_HASH
USER_HASH="$CATBOX_HASH"
PICTURES_DIR="$HOME/Pictures"
# List the folders inside ~/Pictures you want to archive
FOLDERS=("wallpapers" "sddm_backrgounds" "grub_backgrounds" "pfps")

# Colors
GREEN='\033[0;32m'
NC='\033[0m'

echo "📦 Starting Archive & Upload process..."

for FOLDER in "${FOLDERS[@]}"; do
    if [ -d "$PICTURES_DIR/$FOLDER" ]; then
        FILE_NAME="${FOLDER}_$(date +%Y%m%d).tar.gz"
        
        echo -e "Archiving ${GREEN}$FOLDER${NC}..."
        # Create a compressed tarball
        tar -czf "$FILE_NAME" -C "$PICTURES_DIR" "$FOLDER"

        echo "Uploading to Catbox..."
        # Upload using the Catbox API
        RESPONSE=$(curl -F "reqtype=fileupload" \
                        -F "userhash=$USER_HASH" \
                        -F "fileToUpload=@$FILE_NAME" \
                        https://catbox.moe/user/api.php)

        echo -e "✅ Upload Complete! Link: ${GREEN}$RESPONSE${NC}"
        
        # Save the link to a local file for your setup script
        echo "$FOLDER: $RESPONSE" >> ~/dotfiles/catbox_links.txt

        # Cleanup the temporary archive
        rm "$FILE_NAME"
    else
        echo "⚠️ Folder $FOLDER not found in $PICTURES_DIR, skipping."
    fi
done

echo "🎉 All folders processed. Links saved to cloud_links.txt"
