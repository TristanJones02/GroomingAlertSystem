#!/bin/bash

# Raspberry Pi Announcement Server Setup Script
# Run this script on your Raspberry Pi to set up the announcement server

echo "Setting up Raspberry Pi Announcement Server..."

# Update system
echo "Updating system packages..."
sudo apt-get update

# Install required audio players
echo "Installing audio players..."
sudo apt-get install -y mpg123 omxplayer

# Create audio directory
mkdir -p ~/announcement-server/audio

# Copy the Python script and update script
cp announcement_server.py ~/announcement-server/
cp update-audio.sh ~/announcement-server/
chmod +x ~/announcement-server/announcement_server.py
chmod +x ~/announcement-server/update-audio.sh

# Open firewall port (for UFW)
if command -v ufw &> /dev/null; then
    echo "Opening port 8080 in UFW firewall..."
    sudo ufw allow 8080/tcp
    sudo ufw reload
fi

# Open firewall port (for iptables)
echo "Opening port 8080 in iptables..."
sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
sudo netfilter-persistent save 2>/dev/null || sudo iptables-save > /etc/iptables/rules.v4 2>/dev/null

# Create systemd service
echo "Creating systemd service..."
sudo tee /etc/systemd/system/announcement-server.service > /dev/null <<EOF
[Unit]
Description=Grooming Announcement Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/home/$USER/announcement-server
ExecStart=/usr/bin/python3 /home/$USER/announcement-server/announcement_server.py
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable announcement-server.service

echo "Setup complete!"
echo ""
echo "Next steps:"
echo "1. Edit ~/announcement-server/update-audio.sh and set your GitHub repository URL"
echo "2. Run: ~/announcement-server/update-audio.sh (to pull audio files from GitHub)"
echo "3. Start the server with: sudo systemctl start announcement-server"
echo "4. Check status with: sudo systemctl status announcement-server"
echo "5. View logs with: sudo journalctl -u announcement-server -f"
echo ""
echo "To update audio files later, run: ~/announcement-server/update-audio.sh"
echo "The server will start automatically on boot."