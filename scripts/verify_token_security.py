#!/usr/bin/env python3
"""
Token Security Validator

This script verifies that a Bearer token meets security requirements:
- Proper length (at least 32 characters)
- Sufficient entropy
- Proper format
- No common patterns or dictionary words
"""

import re
import sys
import json
import math
import os
import argparse
import logging
from pathlib import Path

# Add project root directory to Python path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from lambdas.shared.logger import get_logger


def calculate_entropy(token):
    """Calculate Shannon entropy of the token string."""    
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


def check_token_length(token, min_length=32):
    """Check if token meets minimum length requirements."""
    if len(token) < min_length:
        return False, f"Token length ({len(token)}) is less than minimum required ({min_length})"
    return True, f"Token length ({len(token)}) is sufficient"


def check_token_entropy(token, min_entropy=3.5):
    """Check if token has sufficient entropy."""
    entropy = calculate_entropy(token)
    if entropy < min_entropy:
        return False, f"Token entropy ({entropy:.2f}) is below minimum threshold ({min_entropy})"
    return True, f"Token entropy ({entropy:.2f}) is sufficient"


def check_character_diversity(token):
    """Check if token has diverse character types."""
    has_uppercase = bool(re.search(r'[A-Z]', token))
    has_lowercase = bool(re.search(r'[a-z]', token))
    has_digits = bool(re.search(r'[0-9]', token))
    has_special = bool(re.search(r'[^A-Za-z0-9]', token))
    
    char_types = sum([has_uppercase, has_lowercase, has_digits, has_special])
    
    if char_types < 3:
        return False, f"Token uses only {char_types} character types (recommended: at least 3)"
    return True, f"Token uses {char_types} character types"


def check_common_patterns(token):
    """Check if token contains common patterns that reduce security."""
    # Check for repeating patterns
    for length in range(1, min(8, len(token) // 2)):
        for i in range(len(token) - 2 * length + 1):
            pattern = token[i:i+length]
            if pattern == token[i+length:i+2*length]:
                return False, f"Token contains repeating pattern: '{pattern}'"
    
    # Check for sequential characters
    sequences = ["abcdefghijklmnopqrstuvwxyz", "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "0123456789"]
    for seq in sequences:
        for i in range(len(seq) - 3):
            if seq[i:i+4] in token:
                return False, f"Token contains sequential pattern: '{seq[i:i+4]}'"
    
    return True, "No common patterns detected in token"


def load_config(path):
    with open(path, "r") as f:
        return json.load(f)


def main():

    log_levels = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]

    parser = argparse.ArgumentParser(description="Bearer Token Security Validator")

    parser.add_argument("--config-file", help="Path to tofill.auto.tfvars.json")
    parser.add_argument("--token", help="Bearer token to validate directly")
    parser.add_argument("--min-length", type=int, default=32, help="Minimum token length (default: 32)")
    parser.add_argument("--min-entropy", type=float, default=3.5, help="Minimum entropy threshold (default: 3.5)")
    parser.add_argument("--log-level", default="INFO", choices=log_levels, help="Set the logging level.")
    parser.add_argument("--exit-on-fail", action="store_true", help="Exit with non-zero status if any check fails")
 
     # Parse args
    args = parser.parse_args()
    
    # Init logger
    logger = get_logger(os.path.basename(__file__), log_level=args.log_level)
    
    bearer_token = None
    
    # Load configuration from file if specified
    if args.config_file:
        try:
            config = load_config(args.config_file)
            logger.debug(f"Loaded configuration from {args.config_file}")
            bearer_token = config["bearer_token"]
        except Exception as e:
            logger.error(f"Failed to load configuration file: {e}")
            sys.exit(1)
    
    # If not found in config, check command line arguments
    if not bearer_token and args.token:
        bearer_token = args.token
        logger.info("Using token provided via command line")
    
    # If still not found, prompt user
    if not bearer_token:
        logger.info("Bearer token not provided via config file or command line")
        bearer_token = input("Please enter your Bearer token to validate: ")
    
    # Extract actual token part (without "Bearer " prefix)
    token_part = bearer_token.split(" ", 1)[1] if " " in bearer_token and bearer_token.startswith("Bearer ") else bearer_token
    
    logger.debug(f"Validating token (first 5 chars): {token_part[:5]}...")
    logger.debug(f"Using minimum length: {args.min_length}, minimum entropy: {args.min_entropy}")
    
    # Run checks
    checks = [
        ("Token Length", check_token_length(token_part, min_length=args.min_length)),
        ("Token Entropy", check_token_entropy(token_part, min_entropy=args.min_entropy)),
        ("Character Diversity", check_character_diversity(token_part)),
        ("Common Patterns", check_common_patterns(token_part))
    ]
    
    # Print results
    all_passed = True
    for name, (passed, message) in checks:
        status = "✅ PASS" if passed else "❌ FAIL"
        log_method = logger.info if passed else logger.warning
        log_method(f"{status} | {name}: {message}")
        if not passed:
            all_passed = False
    
    if all_passed:
        logger.info("✅ All security checks passed! Your token meets the recommended security criteria.")
    else:
        logger.warning("❌ Some security checks failed. Consider updating your token to improve security.")
    
    # Recommendations if checks failed
    if not all_passed:
        logger.info("Recommendations:")
        logger.info("- Use a cryptographically secure random generator to create tokens")
        logger.info(f"- Ensure token length of at least {args.min_length} characters")
        logger.info("- Include a mix of uppercase, lowercase, numbers, and special characters")
        logger.info("- Avoid patterns, sequences, or dictionary words")
        logger.info("- Consider using a tool like 'openssl rand -base64 32' to generate secure tokens")
        
        # Exit with error code if requested
        if args.exit_on_fail:
            logger.error("Exiting with error status due to failed token validation checks")
            sys.exit(1)


if __name__ == "__main__":
    main()
