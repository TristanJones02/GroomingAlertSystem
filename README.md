# Grooming Alert System

An Electron app for grooming salons with integrated announcement system via Raspberry Pi.

## Features
- Webview for go.moego.pet with persistent session/cookies
- Header bar with announcement buttons
- Configurable Raspberry Pi connection for audio playback
- Cross-platform (Windows primary target, Mac for development)

## Setup

### Electron App (Windows/Mac)

1. Install dependencies:
```bash
npm install
```

2. Run in development:
```bash
npm start
```

3. Build for Windows (from Mac):
```bash
npm run build-win
```

4. Build for Mac:
```bash
npm run build-mac
```

### Raspberry Pi Setup

**Easy Installation (Recommended):**
```bash
curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/GroomingAlertSystem/main/pi-installer.sh | bash
```

**Manual Installation:**
1. Clone this repository on your Pi:
```bash
git clone <your-repo-url>
cd GroomingAlertSystem/pi-listener
```

2. Run the setup script:
```bash
chmod +x setup.sh
./setup.sh
```

3. Generate API token:
```bash
cd ~/announcement-server
python3 auth.py
```

4. Start the server:
```bash
sudo systemctl start announcement-server
```

**Important:** Save the API token generated during setup - you'll need it for the Electron app.

## Configuration

In the Electron app:
1. Click the Settings button (⚙️) in the header
2. Enter your Raspberry Pi's IP address and port (default: 8080)
3. Enter the API token generated during Pi setup
4. Save settings

## Usage

1. Launch the Electron app
2. Configure the Pi connection in settings
3. Click announcement buttons to play audio on the Pi
4. The webview will maintain session for go.moego.pet

## Architecture

- **Electron App**: Runs on Windows, provides UI and sends HTTP requests
- **Raspberry Pi**: Runs Python server, receives requests and plays audio through speakers
- **Communication**: HTTP POST requests from Electron to Pi