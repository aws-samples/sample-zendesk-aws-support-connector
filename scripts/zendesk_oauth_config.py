#!/usr/bin/env python3

import argparse
import json
import base64
import requests
import uuid
import sys
import os

# Add project root directory to Python path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from lambdas.shared.logger import get_logger

def load_config(path):
    with open(path, "r") as f:
        return json.load(f)

def save_config(path, config):
    with open(path, "w") as f:
        json.dump(config, f, indent=2)

def make_auth_header(email, api_key):
    token_str = f"{email}/token:{api_key}"
    token_bytes = base64.b64encode(token_str.encode())
    return {"Authorization": f"Basic {token_bytes.decode()}"}

def create_oauth_client(subdomain, admin_email, api_key):
    url = f"https://{subdomain}.zendesk.com/api/v2/oauth/clients.json"
    headers = make_auth_header(admin_email, api_key)
    headers["Content-Type"] = "application/json"

    client_data = {
        "client": {
            "name": "Terraform integration",
            "identifier": str(uuid.uuid4()),
            "redirect_uri": "https://example.com"  # dummy URI
        }
    }

    response = requests.post(url, headers=headers, json=client_data)
    response.raise_for_status()
    return response.json()["client"]

def create_oauth_token(subdomain, admin_email, api_key, client_id):
    url = f"https://{subdomain}.zendesk.com/api/v2/oauth/tokens.json"
    headers = make_auth_header(admin_email, api_key)
    headers["Content-Type"] = "application/json"

    token_data = {
        "token": {
            "client_id": client_id,
            "scopes": [
                "tickets:read",
                "tickets:write"
            ]
        }
    }

    response = requests.post(url, headers=headers, json=token_data)
    response.raise_for_status()
    return response.json()["token"]["full_token"]

def main():

    log_levels = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]

    parser = argparse.ArgumentParser(description="Zendesk OAuth config script")
    parser.add_argument("--config-file", required=True, help="Path to tofill.auto.tfvars.json")
    parser.add_argument("--log-level", default="INFO", choices=log_levels, help="Set the logging level.")

    args = parser.parse_args()

    # Init logger
    logger = get_logger(os.path.basename(__file__), log_level=args.log_level)

    try:
        config = load_config(args.config_file)
    except Exception as e:
        logger.error(f"❌ Failed to load config file: {e}")
        sys.exit(1)

    subdomain = config.get("zendesk_subdomain")
    admin_email = config.get("zendesk_admin_email")
    api_key = config.get("zendesk_token")

    if not all([subdomain, admin_email, api_key]):
        logger.error("❌ Missing zendesk_subdomain, zendesk_admin_email or zendesk_token in config")
        sys.exit(1)

    try:
        logger.debug("🔧 Creating OAuth client...")
        client = create_oauth_client(subdomain, admin_email, api_key)
        logger.debug("🔐 Creating OAuth access token...")
        access_token = create_oauth_token(subdomain, admin_email, api_key, client["id"])
    except requests.HTTPError as e:
        logger.error(f"❌ HTTP error: {e.response.status_code} {e.response.text}")
        sys.exit(1)
    except Exception as e:
        logger.error(f"❌ Error during Zendesk API calls: {e}")
        sys.exit(1)

    config["zendesk_oauth_access_token"] = access_token
    save_config(args.config_file, config)
    logger.info(f"✅ Updated config saved to {args.config_file}")

    logger.info(f"🎉 OAuth Access Token created and saved successfully!")

if __name__ == "__main__":
    main()
