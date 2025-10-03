#!/usr/bin/env python3
"""
Simple authentication system for the announcement server
Generates and validates API tokens
"""

import secrets
import hashlib
import time
import json
from pathlib import Path

AUTH_FILE = Path(__file__).parent / "auth_tokens.json"

def generate_token():
    """Generate a secure API token"""
    return secrets.token_urlsafe(32)

def hash_token(token):
    """Hash a token for secure storage"""
    return hashlib.sha256(token.encode()).hexdigest()

def save_token(token_name, token):
    """Save a hashed token to file"""
    tokens = load_tokens()
    tokens[token_name] = {
        "hash": hash_token(token),
        "created": time.time()
    }
    
    with open(AUTH_FILE, 'w') as f:
        json.dump(tokens, f, indent=2)

def load_tokens():
    """Load tokens from file"""
    if not AUTH_FILE.exists():
        return {}
    
    try:
        with open(AUTH_FILE, 'r') as f:
            return json.load(f)
    except (json.JSONDecodeError, FileNotFoundError):
        return {}

def validate_token(token):
    """Validate a provided token"""
    if not token:
        return False
    
    token_hash = hash_token(token)
    tokens = load_tokens()
    
    for token_data in tokens.values():
        if token_data["hash"] == token_hash:
            return True
    
    return False

def create_default_token():
    """Create a default token for initial setup"""
    token = generate_token()
    save_token("default", token)
    return token

if __name__ == "__main__":
    # Create a default token
    token = create_default_token()
    print(f"Generated API token: {token}")
    print(f"Save this token securely - it will be needed for the Electron app")
    print(f"Tokens are stored in: {AUTH_FILE}")