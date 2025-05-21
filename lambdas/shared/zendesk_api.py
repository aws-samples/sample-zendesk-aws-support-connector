import json
import urllib.request
import os
from shared.secrets import get_secret

ZENDESK_SUBDOMAIN = os.environ['ZENDESK_SUBDOMAIN']

def update_zendesk_ticket(ticket_id: str, comment: str, solve: bool = False):
    # Récupère le token d'accès OAuth stocké dans les secrets
    access_token = get_secret("zendesk_oauth_access_token")
    
    url = f"https://{ZENDESK_SUBDOMAIN}.zendesk.com/api/v2/tickets/{ticket_id}.json"

    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {access_token}"
    }

    data = {
        "ticket": {
            **({"status": "solved"} if solve else {}),
            "comment": {
                "body": comment
            }
        }
    }

    req = urllib.request.Request(url, data=json.dumps(data).encode(), headers=headers, method="PUT")
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read().decode())
