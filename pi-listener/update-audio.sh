#!/bin/bash

# Update audio files from GitHub repository
# Run this script on the Raspberry Pi to pull latest audio files

REPO_URL="https://github.com/YOUR_USERNAME/GroomingAlertSystem.git"
TEMP_DIR="/tmp/grooming-update"
AUDIO_DIR="$HOME/announcement-server/audio"

echo "Updating audio files from GitHub..."

# Clone/update repository
if [ -d "$TEMP_DIR" ]; then
    echo "Updating existing repository..."
    cd "$TEMP_DIR"
    git pull
else
    echo "Cloning repository..."
    git clone "$REPO_URL" "$TEMP_DIR"
fi

# Copy audio files
if [ -d "$TEMP_DIR/assets/audio" ]; then
    echo "Copying audio files..."
    mkdir -p "$AUDIO_DIR"
    cp "$TEMP_DIR/assets/audio"/*.mp3 "$AUDIO_DIR/" 2>/dev/null || echo "No MP3 files found"
    
    echo "Audio files updated:"
    ls -la "$AUDIO_DIR"/*.mp3 2>/dev/null || echo "No audio files in directory"
    
    # Restart service to ensure changes take effect
    echo "Restarting announcement server..."
    sudo systemctl restart announcement-server
    
    echo "Update complete!"
else
    echo "Error: Audio directory not found in repository"
    exit 1
fi