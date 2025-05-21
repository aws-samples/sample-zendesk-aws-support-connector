import json
import boto3
from shared.logger import get_logger
from shared.dynamo_utils import get_lookup_id
from shared.secrets import get_secret
from shared.zendesk_api import update_zendesk_ticket

logger = get_logger()
support = boto3.client('support')


def handle_add_communication(event_detail):
    try:
        case_id = event_detail.get('case-id')
        if not case_id:
            raise ValueError("Missing 'case-id' in event")

        # Lookup corresponding Zendesk ticket
        ticket_id = get_lookup_id(case_id)
        logger.info(f"📌 Found Zendesk ticket ID {ticket_id} for AWS case {case_id}")

        # Get latest AWS Support message
        communications = support.describe_communications(caseId=case_id, maxResults=10)
        is_solved = support.describe_cases(caseIdList=[case_id])['cases'][0]['status'] == 'resolved'
        latest_message = communications['communications'][0]['body']

        # Update the Zendesk ticket
        update_zendesk_ticket(ticket_id=ticket_id, comment=latest_message, solve=is_solved)
        logger.info(f"✅ Added communication to Zendesk ticket {ticket_id}")

        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Zendesk ticket updated"})
        }

    except Exception as e:
        logger.exception("❌ Error while adding communication to Zendesk")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": "Failed to update Zendesk ticket", "error": str(e)})
        }


def handle_resolve_case(event_detail):
    try:
        case_id = event_detail.get('case-id')
        if not case_id:
            raise ValueError("Missing 'case-id' in event")

        # Lookup Zendesk ticket
        ticket_id = get_lookup_id(case_id)
        logger.info(f"📌 Resolving Zendesk ticket ID {ticket_id} for case {case_id}")

        # Mark Zendesk ticket as solved
        update_zendesk_ticket(ticket_id=ticket_id, comment="Case resolved.", solve=True)

        logger.info(f"✅ Zendesk ticket {ticket_id} marked as solved")

        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Zendesk ticket resolved"})
        }

    except Exception as e:
        logger.exception("❌ Error while resolving Zendesk ticket")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": "Failed to resolve Zendesk ticket", "error": str(e)})
        }


def lambda_handler(event, context):
    try:
        logger.info(f"📥 Event received: {json.dumps(event)}")
        detail = event.get('detail', {})
        event_name = detail.get('event-name')
        event_origin = detail.get('origin', 'unknown')

        # Skip if not from AWS
        if event_origin != "AWS":
            logger.warning("Event not from AWS, skipping.")
            return {"statusCode": 200, "body": json.dumps({"message": "Ignored non-AWS event."})}


        if event_name == "AddCommunicationToCase":
            return handle_add_communication(detail)

        if event_name == "ResolveCase":
            return handle_resolve_case(detail)

        logger.warning(f"⚠️ Unhandled event type: {event_name}")
        return {
            "statusCode": 400,
            "body": json.dumps({"message": f"Unhandled event type: {event_name}"})
        }

    except Exception as e:
        logger.exception("❌ Error in lambda handler")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": "Internal server error", "error": str(e)})
        }
