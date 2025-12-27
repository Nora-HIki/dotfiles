#!/bin/bash

# --- CONFIGURATION ---
USER_NAME="{{username}}"
VID_DIR="/home/$USER_NAME/Pictures/sddm_backrgounds"
SDDM_THEME_DIR="/usr/share/sddm/themes/silent/backgrounds"

# --- 1. FIND A RANDOM VIDEO ---
# Supports mp4, webm, and mkv
RANDOM_VIDEO=$(find "$VID_DIR" -type f \( -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" \) | shuf -n 1)

# Check if we actually found a video
if [[ -z "$RANDOM_VIDEO" ]]; then
    echo "Error: No videos found in $VID_DIR"
    exit 1
fi

echo "Selected Video: $RANDOM_VIDEO"

# --- 2. PREPARE TARGET DIRECTORY ---
# Ensure the directory exists
sudo mkdir -p "$SDDM_THEME_DIR"

# --- 3. EXTRACT THE FIRST FRAME ---
# -i: input file
# -ss 00:00:00: start at the very beginning
# -vframes 1: extract exactly one frame
# -q:v 2: high quality output
# -y: overwrite existing file
echo "Extracting first frame..."
sudo ffmpeg -y -i "$RANDOM_VIDEO" -ss 00:00:00 -vframes 1 -q:v 2 "$SDDM_THEME_DIR/background.png" -loglevel error

# --- 4. COPY THE VIDEO ---
echo "Copying video to SDDM theme..."
sudo cp "$RANDOM_VIDEO" "$SDDM_THEME_DIR/background.mp4"

# --- 5. FIX PERMISSIONS ---
# SDDM needs to be able to read these files
sudo chmod 644 "$SDDM_THEME_DIR/background.png"
sudo chmod 644 "$SDDM_THEME_DIR/background.mp4"

echo "SDDM Background updated successfully!"

