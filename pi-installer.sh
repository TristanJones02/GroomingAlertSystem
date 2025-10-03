#!/bin/bash

# Raspberry Pi Grooming Alert System Remote Installer
# This script downloads and installs the announcement server from GitHub
# Run with: curl -sSL https://raw.githubusercontent.com/TristanJones02/GroomingAlertSystem/main/pi-installer.sh | bash

set -e  # Exit on any error

REPO_URL="https://github.com/TristanJones02/GroomingAlertSystem.git"
INSTALL_DIR="$HOME/announcement-server"
TEMP_DIR="/tmp/grooming-install-$(date +%s)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

check_requirements() {
    log "Checking system requirements..."
    
    # Check if running on Raspberry Pi
    if ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
        warn "This doesn't appear to be a Raspberry Pi. Continuing anyway..."
    fi
    
    # Check for required commands
    for cmd in git python3 systemctl; do
        if ! command -v $cmd &> /dev/null; then
            error "$cmd is required but not installed. Please install it first."
        fi
    done
    
    # Check if running as non-root user
    if [ "$EUID" -eq 0 ]; then
        error "Please run this script as a non-root user (not with sudo)"
    fi
}

download_repository() {
    log "Downloading repository from GitHub..."
    
    # Clean up any existing temp directory
    rm -rf "$TEMP_DIR"
    
    # Try downloading as zip file first (no auth required)
    if command -v wget &> /dev/null; then
        log "Downloading repository as ZIP file..."
        wget -q "https://github.com/TristanJones02/GroomingAlertSystem/archive/refs/heads/main.zip" -O "/tmp/repo.zip"
        if command -v unzip &> /dev/null; then
            unzip -q "/tmp/repo.zip" -d "/tmp/"
            mv "/tmp/GroomingAlertSystem-main" "$TEMP_DIR"
            rm "/tmp/repo.zip"
        else
            error "unzip is required but not installed. Please install unzip first."
        fi
    elif command -v curl &> /dev/null; then
        log "Downloading repository as ZIP file..."
        curl -sL "https://github.com/TristanJones02/GroomingAlertSystem/archive/refs/heads/main.zip" -o "/tmp/repo.zip"
        if command -v unzip &> /dev/null; then
            unzip -q "/tmp/repo.zip" -d "/tmp/"
            mv "/tmp/GroomingAlertSystem-main" "$TEMP_DIR"
            rm "/tmp/repo.zip"
        else
            error "unzip is required but not installed. Please install unzip first."
        fi
    else
        # Fallback to git clone
        log "Fallback to git clone..."
        if ! git clone "$REPO_URL" "$TEMP_DIR"; then
            error "Failed to clone repository. Please check the URL and your internet connection."
        fi
    fi
    
    # Verify required files exist
    if [ ! -f "$TEMP_DIR/pi-listener/announcement_server.py" ]; then
        error "Required files not found in repository"
    fi
}

install_dependencies() {
    log "Installing system dependencies..."
    
    # Update package list
    sudo apt-get update
    
    # Set non-interactive mode
    export DEBIAN_FRONTEND=noninteractive
    
    # Install required packages
    sudo apt-get install -y \
        python3 \
        python3-pip \
        mpg123 \
        alsa-utils \
        ufw \
        fail2ban \
        unzip \
        wget
    
    success "Dependencies installed"
}

setup_security() {
    log "Configuring security settings..."
    
    # Configure UFW firewall
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow 8080/tcp comment "Grooming Alert System"
    sudo ufw --force enable
    
    # Configure fail2ban for SSH protection
    sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF
    
    # Note: Automatic security updates removed to avoid interactive prompts
    # Users can manually run: sudo apt update && sudo apt upgrade
    
    # Configure sysctl for network security
    sudo tee /etc/sysctl.d/99-security.conf > /dev/null <<EOF
# Network security settings
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
EOF
    
    sudo sysctl -p /etc/sysctl.d/99-security.conf
    
    success "Security configuration complete"
}

install_application() {
    log "Installing Grooming Alert System..."
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    
    # Copy application files
    cp "$TEMP_DIR/pi-listener/announcement_server.py" "$INSTALL_DIR/"
    cp "$TEMP_DIR/pi-listener/update-audio.sh" "$INSTALL_DIR/"
    cp "$TEMP_DIR/pi-listener/auth.py" "$INSTALL_DIR/"
    
    # Make scripts executable
    chmod +x "$INSTALL_DIR/announcement_server.py"
    chmod +x "$INSTALL_DIR/update-audio.sh"
    chmod +x "$INSTALL_DIR/auth.py"
    
    # Create audio directory
    mkdir -p "$INSTALL_DIR/audio"
    
    # Create systemd service with security restrictions
    sudo tee /etc/systemd/system/announcement-server.service > /dev/null <<EOF
[Unit]
Description=Grooming Announcement Server
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/python3 $INSTALL_DIR/announcement_server.py
Restart=on-failure
RestartSec=10

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$INSTALL_DIR
CapabilityBoundingSet=
AmbientCapabilities=
SystemCallFilter=@system-service
SystemCallErrorNumber=EPERM
SystemCallArchitectures=native

# Network restrictions
IPAddressDeny=any
IPAddressAllow=localhost
IPAddressAllow=10.0.0.0/8
IPAddressAllow=172.16.0.0/12
IPAddressAllow=192.168.0.0/16

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    sudo systemctl daemon-reload
    sudo systemctl enable announcement-server.service
    
    success "Application installed"
}

configure_application() {
    log "Configuring application..."
    
    # Copy audio files automatically
    if [ -d "$TEMP_DIR/assets/audio" ]; then
        log "Copying audio files..."
        cp "$TEMP_DIR/assets/audio"/*.mp3 "$INSTALL_DIR/audio/" 2>/dev/null || warn "No MP3 files found in repository"
        
        # List copied audio files
        if ls "$INSTALL_DIR/audio"/*.mp3 1> /dev/null 2>&1; then
            log "Audio files copied successfully:"
            ls -la "$INSTALL_DIR/audio"/*.mp3
        fi
    fi
    
    success "Application configured"
}

start_services() {
    log "Starting services..."
    
    # Start fail2ban
    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban
    
    # Start announcement server
    sudo systemctl start announcement-server
    
    # Check service status
    if sudo systemctl is-active --quiet announcement-server; then
        success "Announcement server is running"
    else
        error "Failed to start announcement server"
    fi
}

cleanup() {
    log "Cleaning up..."
    rm -rf "$TEMP_DIR"
}

show_status() {
    echo
    success "Installation complete!"
    echo
    echo "Service status:"
    sudo systemctl status announcement-server --no-pager -l
    echo
    echo "Firewall status:"
    sudo ufw status
    echo
    echo "Audio files:"
    ls -la "$INSTALL_DIR/audio/" 2>/dev/null || echo "No audio files found"
    echo
    echo "Setup Complete! 🎉"
    echo
    echo "Next steps:"
    echo "1. Configure your Electron app with this Pi's IP address: $(hostname -I | awk '{print $1}')"
    echo "2. Test announcements from the Electron app"
    echo "3. To update audio files later: $INSTALL_DIR/update-audio.sh"
    echo "4. To view logs: sudo journalctl -u announcement-server -f"
    echo "5. To restart service: sudo systemctl restart announcement-server"
}

main() {
    echo
    log "Grooming Alert System - Raspberry Pi Installer"
    echo
    
    check_requirements
    download_repository
    install_dependencies
    setup_security
    install_application
    configure_application
    start_services
    cleanup
    show_status
}

# Run main function
main "$@"