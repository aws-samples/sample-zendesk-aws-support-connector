#!/usr/bin/env python3
"""
Zendesk Configuration for AWS Support API Integration.

This script automates the setup of Zendesk configuration required for the
zendesk-aws-support integration as described in the README.md file.
It creates custom fields, webhooks, and triggers in Zendesk.

The script can retrieve credentials from AWS Secrets Manager or directly from command line arguments.
"""

import os
import argparse
import json
import sys
import logging
import requests
from typing import Dict, List, Any, Optional

# Add project root directory to Python path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from lambdas.shared.logger import get_logger
from lambdas.shared.secrets import get_secret


class ZendeskConfigurator:
    """Class to handle Zendesk configuration for AWS Support integration."""

    # Custom field constants
    FIELD_AWS_SERVICE = "AWS Service"
    FIELD_AWS_CATEGORY = "Category Code"
    FIELD_AWS_SEVERITY = "Severity"
    # Webhook constants
    WEBHOOK_AWS_CREATE = "aws support - create"
    WEBHOOK_AWS_UPDATE = "aws support - update"
    WEBHOOK_AWS_SOLVED = "aws support - solved"
    # Trigger constants
    TRIGGER_CATEGORY = "AWS Support"
    TRIGGER_AWS_CREATE = "create_ticket_trigger"
    TRIGGER_AWS_UPDATE = "update_ticket_trigger"
    TRIGGER_AWS_SOLVED = "solved_ticket_trigger"
    # Ticket form constants
    TICKET_FORM_NAME = "AWS Support Request"


    def __init__(self, 
                 subdomain: str, 
                 email: str, 
                 api_gateway_url: str,
                 api_token: str = None, 
                 bearer_token: str = None,
                 use_secrets_manager: bool = False,
                 region: str = None,
                 log_level: str = logging.INFO):
        """
        Initialize the Zendesk configurator.
        
        Args:
            subdomain: Zendesk subdomain (e.g., 'companyname' from 'companyname.zendesk.com')
            email: Admin email for Zendesk
            api_gateway_url: AWS API Gateway URL for webhooks.
            api_token: Zendesk API token.
            bearer_token: Bearer token for webhook authentication.
            use_secrets_manager: (boolean) Use AWS Secrets Manager to retrieve credentials.
            region: AWS region where the secret is located.
        """
        self.log_level = log_level
        self.logger = get_logger(log_level=self.log_level)
        self.subdomain = subdomain
        self.email = email
        self.api_gateway_url = api_gateway_url
        self.subdomain = subdomain
        self.api_token = api_token
        self.bearer_token = bearer_token

        # AWS Secrets Manager
        if use_secrets_manager:
            try:
                self.logger.debug("Getting Credentials from AWS Secrets Manager.")
                self.api_token = get_secret("zendesk_api_key", region)
                self.bearer_token = get_secret("zendesk_api_gateway_key", region)
                self.logger.debug("Credentials gathered successfully.")
            except Exception as e:
                self.logger.error(f"Failed to retrieve credentials from Secrets Manager: {e}")
                raise e
        
        # Store resources IDs
        self.webhooks = {
            self.WEBHOOK_AWS_CREATE: "create",
            self.WEBHOOK_AWS_UPDATE: "update",
            self.WEBHOOK_AWS_SOLVED: "solved"
        }
        self.webhook_ids = {}
        self.trigger_ids = {}
        self.ticket_form_id = None
        self.trigger_category_id = None
        self.system_fields = ["subject", "description"]
        self.system_field_ids = self.get_resource_ids("ticket_fields", self.system_fields, "type")
        self.custom_fields = {
            self.FIELD_AWS_SERVICE: ["SageMaker"],
            self.FIELD_AWS_CATEGORY: ["iam", "feature-request", "performance-issue", "general-guidance-framework"],
            self.FIELD_AWS_SEVERITY: ["urgent", "high", "normal", "low", "critical"]
        }
        self.custom_field_ids = {}

    def _make_request(self, method: str, endpoint: str, data: Optional[Dict] = None) -> Dict:
        """
        Make an API request to Zendesk.
        
        Args:
            method: HTTP method (GET, POST, PUT, DELETE)
            endpoint: API endpoint
            data: Request payload
            
        Returns:
            Response data as dictionary
        """
        headers = {"Content-Type": "application/json"}
        auth = (f"{self.email}/token", self.api_token)
        base_url = f"https://{self.subdomain}.zendesk.com/api/v2"
        url = f"{base_url}/{endpoint}"
        
        try:
            if method == "GET":
                response = requests.get(url, auth=auth, headers=headers)
            elif method == "POST":
                response = requests.post(url, auth=auth, headers=headers, json=data)
            elif method == "PUT":
                response = requests.put(url, auth=auth, headers=headers, json=data)
            elif method == "DELETE":
                response = requests.delete(url, auth=auth, headers=headers)
                # DELETE requests may return empty responses
                if not response.content:
                    return {}
            else:
                raise ValueError(f"Unsupported HTTP method: {method}")
            
            response.raise_for_status()
            # Only try to parse JSON if there's content
            if response.content:
                return response.json()
            return {}
        except requests.exceptions.RequestException as e:
            self.logger.error(f"Error making request to {url}: {e}")
            raise e
    
    def get_resource_id(self, type: str, name: str, attribute: str) -> int:
        """
        Retrieve a Zendesk resource ID from its name.
        
        Args:
            type: Resource type (e.g. "trigger_categories", "ticket_fields", etc.).
            name: Resource name.
            attribute: Attribute used for comparison (e.g. "name", "title", etc.).
            
        Returns:
            ID of the trigger category.
        """
        # Check if resource exists
        self.logger.debug(f"Searching for resource '{name}' of type '{type}'")     
        existing_resources = self._make_request("GET", type)
        for resource in existing_resources.get(type, []):
            if resource[attribute] == name:
                self.logger.debug(f"Found ID for resource '{name}' of type '{type}': {resource["id"]}")
                return resource["id"]
        return None


    def get_resource_ids(self, type: str, names: List[str], attribute: str) -> Dict[str, int]:
        """
        Retrieve a list of Zendesk resource IDs (same type) from their names.

        Args:
            type: Resources type (e.g. "trigger_categories", "ticket_fields", etc.).
            names: List of resource names.
            attribute: Attribute used for comparison (e.g. "name", "title", etc.).
            
        Returns:
            Dict of resource names and IDs mapping.
        """
        self.logger.debug(f"Searching for resources '{names}' of type '{type}'")     

        # Get all resources
        resources = self._make_request("GET", type)
        resource_id_mapping = {}

        for resource in resources.get(type, []):
            if resource[attribute] in names:
                resource_id_mapping[resource[attribute]] = resource["id"]
        
        self.logger.debug(f"Found resource IDs of type '{type}': {resource_id_mapping}")

        return resource_id_mapping

    def delete_resource(self, type: str, id: Any):
        """
        Delete a Zendesk resource using its ID.

        Args:
            type: Resource type (e.g. "trigger_categories", "ticket_fields", etc.).
            name: Resource name.
            
        """
        self.logger.info(f"Deleting resource '{id}' of type '{type}'.")
        try:
            self._make_request("DELETE", f"{type}/{id}")
            self.logger.info(f"Successfully deleted resource '{id}' of type '{type}'.")
        except Exception as e:
            self.logger.error(f"Failed to delete resource '{id}' of type '{type}': {e}")
            raise e

    def create_custom_field(self, title: str, field_type: str, options: List[str]) -> int:
        """
        Create a Zendesk custom field or get its ID if it already exists.
        Doc: https://developer.zendesk.com/api-reference/ticketing/tickets/ticket_fields/
        
        Args:
            title: Field title (name).
            field_type: Type of the field (e.g., 'dropdown').
            options: List of field options.
            
        Returns:
            ID of the created custom field
        """
        self.logger.info(f"Creating or getting custom field: '{title}'.")
        
        # Check if field already exists
        field_id = self.get_resource_id("ticket_fields", title, "title")
        if field_id:
            self.logger.info(f"Custom field '{title}' already exists, skipping creation.")
            self.custom_field_ids[title] = field_id
            return field_id
        
        # If not, create new field
        custom_field_data = {
            "ticket_field": {
                "type": field_type,
                "title": title,
                "description": f"Custom field for AWS Support integration: {title}",
                "position": 1,
                "active": True,
                "required": False,
                "collapsed_for_agents": False,
                "regexp_for_validation": "",
                "title_in_portal": title,
                "visible_in_portal": True,
                "editable_in_portal": True,
                "required_in_portal": False,
                "custom_field_options": [{"name": option, "value": option} for option in options]
            }
        }
        
        response = self._make_request("POST", "ticket_fields", custom_field_data)
        field_id = response["ticket_field"]["id"]
        self.logger.info(f"Created custom field '{title}' with ID: {field_id} .")
        self.custom_field_ids[title] = field_id
        return field_id
    
    def create_ticket_form(self, name: str, field_ids: List[int]) -> int:
        """
        Create a Zendesk ticket form or get its ID if it already exists.
        Doc: https://developer.zendesk.com/api-reference/ticketing/tickets/ticket_forms/
        
        Args:
            name: Form name
            field_ids: List of field IDs to include in the form
            
        Returns:
            ID of the created ticket form
        """
        self.logger.info(f"Creating or getting ticket form: '{name}'.")

        # Return ticket form if found
        form_id = self.get_resource_id("ticket_forms", name, "name")
        if form_id:
            self.logger.info(f"Ticket form '{name}' already exists, skipping creation.")
            self.ticket_form_id = form_id
            return form_id
        
        # If not, create new form
        form_data = {
            "ticket_form": {
                "name": name,
                "display_name": name,
                "active": True,
                "default": False,
                "in_all_brands": True,
                "end_user_visible": True,
                "ticket_field_ids": field_ids
            }
        }
        
        response = self._make_request("POST", "ticket_forms", form_data)
        form_id = response["ticket_form"]["id"]
        self.logger.info(f"Created ticket form '{name}' with ID: {form_id} .")
        self.ticket_form_id = form_id
        return form_id

    def create_webhook(self, name: str, endpoint_path: str) -> int:
        """
        Create a Zendesk webhook or get its ID if it already exists..
        Doc: https://developer.zendesk.com/api-reference/webhooks/webhooks-api/webhooks/
        
        Args:
            name: Webhook name
            endpoint_path: Path to append to the API Gateway URL
            
        Returns:
            ID of the created webhook or get its ID if it already exists.
        """
        self.logger.info(f"Creating or getting webhook: '{name}' .")
        
        # Return webhook if found
        webhook_id = self.get_resource_id("webhooks", name, "name")
        if webhook_id:
            self.logger.info(f"Webhook '{name}' already exists, skipping creation.")
            self.webhook_ids[name] = webhook_id
            return webhook_id
        
        # If not, create new webhook
        webhook_data = {
            "webhook": {
                "name": name,
                "endpoint": f"{self.api_gateway_url}/{endpoint_path}",
                "http_method": "POST",
                "request_format": "json",
                "authentication": {
                    "add_position": "header",
                    "type": "bearer_token",
                    "data": {
                        "token": self.bearer_token
                    }
                },
                "status": "active"
            }
        }
        
        response = self._make_request("POST", "webhooks", webhook_data)
        webhook_id = response["webhook"]["id"]
        self.logger.info(f"Created webhook '{name}' with ID: {webhook_id} .")
        self.webhook_ids[name] = webhook_id
        return webhook_id

    def create_trigger_category(self, name: str) -> int:
        """
        Create a Zendesk trigger category or get its ID if it already exists.
        Doc: https://developer.zendesk.com/api-reference/ticketing/business-rules/trigger_categories/
        
        Args:
            name: Category name
            
        Returns:
            ID of the created or existing trigger category
        """
        self.logger.info(f"Creating or getting trigger category: '{name}'.")
        
        # Return trigger category if found
        category_id = self.get_resource_id("trigger_categories", name, "name")
        if category_id:
            self.logger.info(f"Trigger category '{name}' already exists, skipping creation.")
            self.trigger_category_id = category_id
            return category_id
        
        # If not, create new trigger category
        category_data = { "trigger_category": { "name": name } }  
        response = self._make_request("POST", "trigger_categories", category_data)
        category_id = response["trigger_category"]["id"]
        self.logger.info(f"Created trigger category '{name}' with ID: {category_id} .")
        self.trigger_category_id = category_id
        return category_id

    def create_trigger(self, title: str, conditions: Dict, actions: Dict) -> int:
        """
        Create a Zendesk trigger or get its ID if it already exists.
        Doc: https://developer.zendesk.com/api-reference/ticketing/business-rules/triggers/
        
        Args:
            title: Trigger title (name)
            conditions: Trigger conditions
            actions: Trigger actions
            
        Returns:
            ID of the created trigger
        """
        self.logger.info(f"Creating or getting trigger: '{title}'.")
        
        # Return trigger if found
        trigger_id = self.get_resource_id("triggers", title, "title")
        if trigger_id:
            self.logger.info(f"Trigger '{title}' already exists, skipping creation.")
            self.trigger_ids[title] = trigger_id
            return trigger_id
        
        # If not, create new trigger
        trigger_data = {
            "trigger": {
                "title": title,
                "active": True,
                "position": 0,
                "category_id": self.trigger_category_id,
                "conditions": conditions,
                "actions": actions
            }
        }
        
        response = self._make_request("POST", "triggers", trigger_data)
        trigger_id = response["trigger"]["id"]
        self.logger.info(f"Created trigger '{title}' with ID: {trigger_id} .")
        self.trigger_ids[title] = trigger_id
        return trigger_id
    
    def print_resources(self):
        """Show created Zendesk resources."""
        # Custom fields
        self.logger.info("Custom Fields:")
        for name, field_id in self.custom_field_ids.items():
            self.logger.info(f"Field = '{name}' (ID = {field_id})")
        
        # Webhooks
        self.logger.info("Webhooks:")
        for name, webhook_id in self.webhook_ids.items():
            self.logger.info(f"Webhook = '{name}' (ID = {webhook_id})")
        
        # Trigger category
        self.logger.info(f"Trigger Category = '{self.TRIGGER_CATEGORY}' (ID = {self.trigger_category_id})")
        
        # Triggers
        self.logger.info("Triggers:")
        for name, trigger_id in self.trigger_ids.items():
            self.logger.info(f"Trigger = '{name}' (ID = {trigger_id})")
            
        # Display custom form URL
        if self.ticket_form_id:
            form_url = f"https://{self.subdomain}.zendesk.com/hc/requests/new?ticket_form_id={self.ticket_form_id}"
            self.logger.info(f"Zendesk custom form URL: {form_url}")

    def setup_zendesk_configuration(self):
        """Set up all required Zendesk configurations."""
        self.logger = get_logger("zendesk_setup", log_level=self.log_level)
        self.logger.info("Starting Zendesk configuration setup...")
        
        # Create custom dropdown fields ("tagger" type)
        for custom_field_name, custom_field_options in self.custom_fields.items():
            self.create_custom_field(
                custom_field_name,
                "tagger",
                custom_field_options
            )
        
        # Create an AWS Support ticket form with all fields
        field_ids = [*self.system_field_ids.values(), *self.custom_field_ids.values()]
        self.create_ticket_form(self.TICKET_FORM_NAME, field_ids)
        
        # Create webhooks
        for name, endpoint_path in self.webhooks.items():
            self.create_webhook(name, endpoint_path)
        
        # Create trigger category for AWS Support
        self.create_trigger_category(self.TRIGGER_CATEGORY)

        # "Create" trigger
        create_trigger_conditions = {
            "all": [
                {"field": "update_type", "operator": "is", "value": "Create"}
                ],
            "any": []
        }
        
        create_trigger_actions = [
            {
                "field": "notification_webhook",
                "value": [
                    self.webhook_ids[self.WEBHOOK_AWS_CREATE],
                    json.dumps({
                        "zd_ticket_id": "{{ticket.id}}",
                        "zd_ticket_desc": "{{ticket.description}}",
                        "zd_ticket_requester_email": "{{ticket.requester.email}}",
                        "zd_ticket_latest_public_comment": "{{ticket.latest_public_comment_html}}",
                        "zd_ticket_impacted_service": f"{{{{ticket.ticket_field_{self.custom_field_ids[self.FIELD_AWS_SERVICE]}}}}}",
                        "zd_ticket_category_code": f"{{{{ticket.ticket_field_{self.custom_field_ids[self.FIELD_AWS_CATEGORY]}}}}}",
                        "zd_ticket_sev_code": f"{{{{ticket.ticket_field_{self.custom_field_ids[self.FIELD_AWS_SEVERITY]}}}}}"
                    })
                ]
            }
        ]
        
        self.create_trigger(self.TRIGGER_AWS_CREATE, create_trigger_conditions, create_trigger_actions)
        
        # "Update" trigger
        update_trigger_conditions = {
            "all": [
                # Ticket is updated
                {"field": "update_type", "operator": "is", "value": "Change"},
                # Ticket update not via web service (API)
                {"field": "current_via_id", "operator": "is_not", "value": "5"}
            ],
            "any": []
        }
        
        update_trigger_actions = [
            {
                "field": "notification_webhook",
                "value": [
                    self.webhook_ids[self.WEBHOOK_AWS_UPDATE],
                    json.dumps({
                        "zd_ticket_id": "{{ticket.id}}",
                        "zd_ticket_desc": "{{ticket.description}}",
                        "zd_ticket_requester_email": "{{ticket.requester.email}}",
                        "zd_ticket_latest_public_comment": "{{ticket.latest_public_comment_html}}"
                    })
                ]
            }
        ]
        
        self.create_trigger(self.TRIGGER_AWS_UPDATE, update_trigger_conditions, update_trigger_actions)
        
        # "Solved" trigger
        
        ## Get "solved" status ID (specific to each Zendesk account)
        solved_status_id = self.get_resource_id("custom_statuses", "solved", "status_category")

        solved_trigger_conditions = {
            "all": [
                # Ticket status changed to "Solved"
                {"field": "custom_status_id", "operator": "value", "value": f"{solved_status_id}"}
            ],
            "any": []
        }
        
        solved_trigger_actions = [
            {
                "field": "notification_webhook",
                "value": [
                    self.webhook_ids[self.WEBHOOK_AWS_SOLVED] ,
                    json.dumps({
                        "zd_ticket_id": "{{ticket.id}}",
                        "zd_ticket_desc": "{{ticket.description}}",
                        "zd_ticket_requester_email": "{{ticket.requester.email}}",
                        "zd_ticket_latest_public_comment": "{{ticket.latest_public_comment_html}}"
                    })
                ]
            }
        ]
        
        self.create_trigger(self.TRIGGER_AWS_SOLVED, solved_trigger_conditions, solved_trigger_actions)
        
        self.logger.info("Zendesk configuration completed successfully!")
        # Show created resources
        self.print_resources()
            
    def delete_zendesk_configuration(self):
        """Delete all Zendesk configurations created for AWS Support integration.
        
        This method first collects all the necessary object IDs using GET requests
        and then deletes each object. It can be executed independently of setup_zendesk_configuration().
        """
        self.logger = get_logger("zendesk_delete", log_level=self.log_level)
        self.logger.info("Starting deletion of Zendesk configuration...")
        
        # Collect custom field IDs if not already set
        if not self.custom_field_ids:
            self.custom_field_ids = self.get_resource_ids("ticket_fields", [
                self.FIELD_AWS_SERVICE,
                self.FIELD_AWS_CATEGORY,
                self.FIELD_AWS_SEVERITY
            ], "title")
        
        # Collect webhook IDs if not already set
        if not self.webhook_ids:
            self.webhook_ids = self.get_resource_ids("webhooks", [
                self.WEBHOOK_AWS_CREATE,
                self.WEBHOOK_AWS_UPDATE,
                self.WEBHOOK_AWS_SOLVED
            ], "name")

        # Collect trigger category ID if not already set
        if not self.trigger_category_id:
            self.trigger_category_id = self.get_resource_id(
                "trigger_categories", 
                self.TRIGGER_CATEGORY, 
                "name")

        # Collect trigger IDs if not already set
        if not self.trigger_ids:
            self.trigger_ids = self.get_resource_ids("triggers", [
                self.TRIGGER_AWS_CREATE,
                self.TRIGGER_AWS_UPDATE,
                self.TRIGGER_AWS_SOLVED
            ], "title")

        # Collect ticket form ID if not already set
        if not self.ticket_form_id:
            self.ticket_form_id = self.get_resource_id(
                "ticket_forms",
                self.TICKET_FORM_NAME,
                "name")
        
        # Delete triggers first (they depend on webhooks)
        for trigger_id in self.trigger_ids.values():
            self.delete_resource("triggers", trigger_id)          

        # Delete trigger category 
        if self.trigger_category_id:
            self.delete_resource("trigger_categories", self.trigger_category_id)

        # Delete webhooks
        for webhook_id in self.webhook_ids.values():
            self.delete_resource("webhooks", webhook_id)
        
        # Delete ticket form
        if self.ticket_form_id:
            self.delete_resource("ticket_forms", self.ticket_form_id)
        
        # Delete custom fields
        for field_id in self.custom_field_ids.values():
            self.delete_resource("ticket_fields", field_id)
        
        self.logger.info("Zendesk configuration deletion completed!")

def load_config(config_file):
    """Load configuration from file"""
    with open(config_file, "r") as f:
        return json.load(f)


def main():
    """Parse arguments and run the configuration."""

    log_levels = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
    
    parser = argparse.ArgumentParser(description="Configure Zendesk for AWS Support Integration")
    
    # Main args
    parser.add_argument("--subdomain", help="Zendesk subdomain (e.g., 'companyname' from 'companyname.zendesk.com').")
    parser.add_argument("--email", help="Zendesk admin email.")
    parser.add_argument("--api-gateway-url", default=None, help="AWS API Gateway URL (without trailing slash).")
    parser.add_argument("--log-level", default="INFO", choices=log_levels, help="Set the logging level.")
    parser.add_argument("--action", default="setup", choices=["setup", "delete"], help="'setup' or 'delete' Zendesk configuration.")
    parser.add_argument("--config-file", help="Path to JSON configuration file (tofill.auto.json).")
    
    # Add credentials args
    parser.add_argument("--use-secrets-manager", action="store_true", help="Use AWS Secrets Manager to retrieve API tokens.")
    parser.add_argument("--api-token", default=None, help="Zendesk API token (if --use-secrets-manager is not set).")
    parser.add_argument("--bearer-token", default=None, help="Bearer token for webhook authentication (if --use-secrets-manager is not set).")
    parser.add_argument("--region", default=None, help="AWS region for Secrets Manager.")
    
    # Parse args
    args = parser.parse_args()

    # Init logger
    logger = get_logger(os.path.basename(__file__), log_level=args.log_level)

    # Load configuration from file if specified
    config = {}
    if args.config_file:
        try:
            config = load_config(args.config_file)
            logger.debug(f"Loaded configuration from {args.config_file}")
        except Exception as e:
            logger.error(f"Failed to load configuration file: {e}")
            sys.exit(1)

    # Set parameters from config file if not provided in command line
    subdomain = args.subdomain or config.get("zendesk_subdomain")
    email = args.email or config.get("zendesk_admin_email")
    api_token = args.api_token or config.get("zendesk_token")
    bearer_token = args.bearer_token or config.get("bearer_token")
    region = args.region or config.get("region")
    
    # Validate required parameters
    if not subdomain:
        logger.error("Zendesk subdomain is required. Provide it via --subdomain or in the config file.")
        sys.exit(1)
    
    if not email:
        logger.error("Zendesk admin email is required. Provide it via --email or in the config file.")
        sys.exit(1)
    
    # Missing credential parameters
    if not args.use_secrets_manager and (not api_token or not bearer_token):      
        logger.error("You must provide both --api-token and --bearer-token when not using AWS Secrets Manager.")
        sys.exit(1)

    # Missing API Gateway parameter when action="setup"
    if not args.api_gateway_url and args.action == "setup":      
        logger.error("You must provide --api-gateway-url when --action=setup.")
        sys.exit(1)
    
    # Zendesk Configurator init
    configurator = ZendeskConfigurator(
        subdomain=subdomain,
        email=email,
        api_gateway_url=args.api_gateway_url,
        api_token=api_token,
        bearer_token=bearer_token,
        use_secrets_manager=args.use_secrets_manager,
        region=region,
        log_level=args.log_level
    )
    
    # Zendesk Config setup case
    if args.action == "setup":
        configurator.setup_zendesk_configuration()
    # Zendesk Config delete case
    elif args.action == "delete":
        configurator.delete_zendesk_configuration()
    else:
        logger.error(f"Unknown action: {args.action}")
        sys.exit(1)


if __name__ == "__main__":
    main()
