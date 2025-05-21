import json
import boto3
from shared.logger import get_logger
from shared.dynamo_utils import get_lookup_id, put_lookup_id

logger = get_logger()
support = boto3.client('support')

def create_support_case(payload_dict):
    try:
        detail = payload_dict['detail']
        response = support.create_case(
            subject="TEST CASE - Please ignore",
            severityCode=detail.get('zd_ticket_sev_code', 'low'),
            categoryCode=detail.get('zd_ticket_category_code', 'other'),
            communicationBody=detail.get('zd_ticket_desc', 'No description'),
            serviceCode=detail.get('zd_ticket_impacted_service', 'other'),
            issueType="customer-service"
        )
        case_id = response['caseId']
        ticket_id = str(detail['zd_ticket_id'])

        put_lookup_id(case_id, ticket_id)
        put_lookup_id(ticket_id, case_id)

        put_lookup_id(case_id.replace("muen", "mufr"), ticket_id)
        put_lookup_id(ticket_id, case_id.replace("muen", "mufr"))

        logger.info(f"✅ Support case created: {case_id}")
        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Case created", "caseId": case_id})
        }

    except Exception as e:
        logger.exception("❌ Failed to create support case")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": "Error", "error": str(e)})
        }

def update_support_case(payload_dict):
    try:
        detail = payload_dict['detail']
        ticket_id = str(detail['zd_ticket_id'])
        case_id = get_lookup_id(ticket_id)

        communication_body = detail.get('zd_ticket_latest_public_comment', 'No comment provided')

        support.add_communication_to_case(
            caseId=case_id,
            communicationBody=communication_body
        )

        logger.info(f"🔁 Updated case {case_id} with new comment.")
        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Case updated", "caseId": case_id})
        }

    except Exception as e:
        logger.exception("❌ Failed to update support case")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": "Error", "error": str(e)})
        }

def solve_support_case(payload_dict):
    try:
        detail = payload_dict['detail']
        ticket_id = str(detail['zd_ticket_id'])
        case_id = get_lookup_id(ticket_id)

        support.resolve_case(caseId=case_id)

        logger.info(f"✅ Case {case_id} resolved.")
        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Case resolved", "caseId": case_id})
        }

    except Exception as e:
        logger.exception("❌ Failed to resolve support case")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": "Error", "error": str(e)})
        }

def lambda_handler(event, context):
    try:
        logger.info(f"📥 Received event: {json.dumps(event)}")
        event_type = event.get('detail-type')

        if event_type == "create.webhook":
            return create_support_case(event)
        elif event_type == "update.webhook":
            return update_support_case(event)
        elif event_type == "solved.webhook":
            return solve_support_case(event)
        else:
            logger.warning(f"⚠️ Unknown event type: {event_type}")
            return {
                "statusCode": 400,
                "body": json.dumps({"message": f"Unhandled event type: {event_type}"})
            }

    except Exception as e:
        logger.exception("❌ Error handling webhook event")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": "Internal error", "error": str(e)})
        }
