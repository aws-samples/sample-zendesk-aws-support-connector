#!/usr/bin/env python3
"""
Secure Token Generator

This script generates cryptographically secure tokens that satisfy the security
requirements checked by verify_token_security.py:
- Sufficient length (configurable, default 48 characters)
- High entropy
- Mix of character types (uppercase, lowercase, numbers, special chars)
- No common patterns or sequences
"""

import os
import sys
import argparse
import secrets
import string
import logging
import re
import math
from pathlib import Path

# Add project root directory to Python path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from lambdas.shared.logger import get_logger


def calculate_entropy(token):
    """Calculate Shannon entropy of the token string."""
    if not token:
        return 0
    
    # Count character frequencies
    char_count = {}
    for char in token:
        if char in char_count:
            char_count[char] += 1
        else:
            char_count[char] = 1
    
    # Calculate entropy
    entropy = 0
    for count in char_count.values():
        probability = count / len(token)
        entropy -= probability * math.log2(probability)
    
    return entropy


def check_character_diversity(token):
    """Check if token has diverse character types."""
    has_uppercase = bool(re.search(r'[A-Z]', token))
    has_lowercase = bool(re.search(r'[a-z]', token))
    has_digits = bool(re.search(r'[0-9]', token))
    has_special = bool(re.search(r'[^A-Za-z0-9]', token))
    
    char_types = sum([has_uppercase, has_lowercase, has_digits, has_special])
    return char_types >= 3


def check_common_patterns(token):
    """Check if token contains common patterns that reduce security."""
    # Check for repeating patterns
    for length in range(1, min(8, len(token) // 2)):
        for i in range(len(token) - 2 * length + 1):
            pattern = token[i:i+length]
            if pattern == token[i+length:i+2*length]:
                return False
    
    # Check for sequential characters
    sequences = ["abcdefghijklmnopqrstuvwxyz", "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "0123456789"]
    for seq in sequences:
        for i in range(len(seq) - 3):
            if seq[i:i+4] in token:
                return False
    
    return True


def generate_secure_token(length=48, min_entropy=4.0):
    """
    Generate a cryptographically secure token that meets all security requirements.
    
    Args:
        length: Desired token length (default: 48)
        min_entropy: Minimum entropy required (default: 4.0)
        
    Returns:
        A secure token string
    """
    # Define character sets
    uppercase = string.ascii_uppercase
    lowercase = string.ascii_lowercase
    digits = string.digits
    special = "!@#$%^&*()-_=+[]{}|;:,.<>?/"
    
    # Ensure we have at least one of each character type
    token_chars = [
        secrets.choice(uppercase),
        secrets.choice(lowercase),
        secrets.choice(digits),
        secrets.choice(special)
    ]
    
    # Fill the rest with random characters from all sets
    all_chars = uppercase + lowercase + digits + special
    token_chars.extend(secrets.choice(all_chars) for _ in range(length - 4))
    
    # Shuffle the characters to avoid predictable positions
    secrets.SystemRandom().shuffle(token_chars)
    token = ''.join(token_chars)
    
    # Check if the token meets our requirements
    entropy = calculate_entropy(token)
    has_diversity = check_character_diversity(token)
    no_patterns = check_common_patterns(token)
    
    # If not, try again recursively
    if entropy < min_entropy or not has_diversity or not no_patterns:
        return generate_secure_token(length, min_entropy)
    
    return token


def update_config_file(config_path, token):
    """Update the configuration file with the new token."""
    import json
    
    try:
        # Read existing config
        with open(config_path, 'r') as f:
            config = json.load(f)
        
        # Update token
        config['bearer_token'] = token
        
        # Write updated config
        with open(config_path, 'w') as f:
            json.dump(config, f, indent=2)
            
        return True, None
    except Exception as e:
        return False, f"Error updating configuration: {str(e)}"


def main():
    log_levels = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
    
    parser = argparse.ArgumentParser(description="Secure Token Generator")
    parser.add_argument("--length", type=int, default=48, help="Token length (default: 48)")
    parser.add_argument("--min-entropy", type=float, default=4.0, help="Minimum entropy (default: 4.0)")
    parser.add_argument("--config-file", help="Path to tofill.auto.tfvars.json to update")
    parser.add_argument("--log-level", default="INFO", choices=log_levels, help="Set the logging level")
    args = parser.parse_args()
    

    # Initialize logger
    logger = get_logger(os.path.basename(__file__), log_level=args.log_level)
    
    # Generate token
    logger.info(f"Generating secure token with length={args.length}, min_entropy={args.min_entropy}...")
    token = generate_secure_token(args.length, args.min_entropy)
    
    # Calculate and display entropy
    entropy = calculate_entropy(token)
    logger.info(f"Token generated successfully with entropy: {entropy:.2f}")
    logger.info(f"Generated token: {token}")
    
    # Update config file if specified
    if args.config_file:
        logger.info(f"Updating configuration file: {args.config_file}")
        success, error = update_config_file(args.config_file, token)
        if success:
            logger.info(f"✅ Configuration file updated successfully")
        else:
            logger.error(f"❌ Failed to update configuration file: {error}")
            sys.exit(1)


if __name__ == "__main__":
    main()
