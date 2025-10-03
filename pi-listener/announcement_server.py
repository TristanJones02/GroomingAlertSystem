#!/usr/bin/env python3
"""
Raspberry Pi Announcement Server
Listens for HTTP requests from the Electron app and plays audio announcements
"""

import os
import json
import logging
import subprocess
import time
import hashlib
import re
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs
from collections import defaultdict, deque

# Configuration
PORT = 8080
AUDIO_DIR = Path(__file__).parent / "audio"
MAX_REQUESTS_PER_MINUTE = 30
MAX_CONTENT_LENGTH = 1024  # 1KB max request size
ALLOWED_AUDIO_FILES = {
    'dog-arrived.mp3',
    'owner-arrived-to-collect.mp3', 
    'assistance-required.mp3'
}

# Rate limiting storage
request_counts = defaultdict(lambda: deque())
blocked_ips = set()

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def is_rate_limited(client_ip):
    """Check if client IP is rate limited"""
    now = time.time()
    minute_ago = now - 60
    
    # Clean old requests
    while request_counts[client_ip] and request_counts[client_ip][0] < minute_ago:
        request_counts[client_ip].popleft()
    
    # Check rate limit
    if len(request_counts[client_ip]) >= MAX_REQUESTS_PER_MINUTE:
        blocked_ips.add(client_ip)
        logger.warning(f"Rate limit exceeded for IP: {client_ip}")
        return True
    
    # Add current request
    request_counts[client_ip].append(now)
    return False

def validate_audio_file(audio_file):
    """Validate audio file name"""
    if not audio_file:
        return False, "No audio file specified"
    
    # Sanitize filename - only allow alphanumeric, hyphens, dots
    if not re.match(r'^[a-zA-Z0-9.-]+$', audio_file):
        return False, "Invalid audio file name"
    
    # Check against whitelist
    if audio_file not in ALLOWED_AUDIO_FILES:
        return False, f"Audio file not allowed: {audio_file}"
    
    return True, None

class AnnouncementHandler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        """Handle CORS preflight requests"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_POST(self):
        """Handle POST requests to play announcements"""
        client_ip = self.client_address[0]
        
        # Security checks
        if client_ip in blocked_ips:
            self.send_error_response(429, "IP blocked due to rate limiting")
            return
            
        if is_rate_limited(client_ip):
            self.send_error_response(429, "Rate limit exceeded")
            return
        
        if self.path == '/play':
            # Validate content length
            content_length = int(self.headers.get('Content-Length', 0))
            if content_length > MAX_CONTENT_LENGTH:
                self.send_error_response(413, "Request too large")
                return
                
            if content_length == 0:
                self.send_error_response(400, "Empty request")
                return
            
            post_data = self.rfile.read(content_length)
            
            try:
                data = json.loads(post_data.decode('utf-8'))
                audio_file = data.get('audio', '')
                
                # Validate audio file
                is_valid, error_msg = validate_audio_file(audio_file)
                if not is_valid:
                    self.send_error_response(400, error_msg)
                    return
                
                # Double-check: sanitize filename to prevent path traversal
                audio_file = os.path.basename(audio_file)
                audio_path = AUDIO_DIR / audio_file
                
                if not audio_path.exists():
                    self.send_error_response(404, f"Audio file not found: {audio_file}")
                    return
                
                # Play audio using omxplayer (Raspberry Pi) or mpg123 as fallback
                try:
                    # Try omxplayer first (Raspberry Pi default)
                    result = subprocess.run(
                        ['omxplayer', '-o', 'local', str(audio_path)],
                        capture_output=True,
                        text=True,
                        timeout=30
                    )
                    if result.returncode != 0:
                        raise subprocess.CalledProcessError(result.returncode, 'omxplayer')
                except (FileNotFoundError, subprocess.CalledProcessError):
                    # Fallback to mpg123
                    try:
                        result = subprocess.run(
                            ['mpg123', str(audio_path)],
                            capture_output=True,
                            text=True,
                            timeout=30
                        )
                    except FileNotFoundError:
                        # Final fallback to aplay for wav files
                        result = subprocess.run(
                            ['aplay', str(audio_path)],
                            capture_output=True,
                            text=True,
                            timeout=30
                        )
                
                logger.info(f"Played announcement: {audio_file}")
                self.send_success_response({"message": f"Playing {audio_file}"})
                
            except json.JSONDecodeError:
                self.send_error_response(400, "Invalid JSON data")
            except subprocess.TimeoutExpired:
                self.send_error_response(500, "Audio playback timeout")
            except Exception as e:
                logger.error(f"Error playing audio: {str(e)}")
                self.send_error_response(500, f"Error playing audio: {str(e)}")
        else:
            self.send_error_response(404, "Endpoint not found")

    def send_success_response(self, data):
        """Send a successful JSON response"""
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode('utf-8'))

    def send_error_response(self, code, message):
        """Send an error JSON response"""
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps({"error": message}).encode('utf-8'))

    def log_message(self, format, *args):
        """Override to use custom logger"""
        logger.info("%s - %s" % (self.address_string(), format % args))

def setup_audio_directory():
    """Create audio directory if it doesn't exist"""
    AUDIO_DIR.mkdir(exist_ok=True)
    
    # Create a README in the audio directory
    readme_path = AUDIO_DIR / "README.txt"
    if not readme_path.exists():
        readme_path.write_text("""Place announcement audio files here:
- dog-arrived.mp3
- owner-arrived-to-collect.mp3
- assistance-required.mp3

Run ~/announcement-server/update-audio.sh to pull files from GitHub
""")
    
    logger.info(f"Audio directory: {AUDIO_DIR.absolute()}")

def main():
    setup_audio_directory()
    
    server = HTTPServer(('0.0.0.0', PORT), AnnouncementHandler)
    logger.info(f"Announcement server listening on port {PORT}")
    logger.info("Press Ctrl+C to stop the server")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
        server.shutdown()

if __name__ == '__main__':
    main()