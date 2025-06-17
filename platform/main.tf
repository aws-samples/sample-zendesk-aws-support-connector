# Main Terraform configuration file for Zendesk AWS Support Connector

# Import security module
module "security" {
  source = "./modules/security"

  # Pass required variables
  region                     = var.region
  bearer_token               = var.bearer_token
  zendesk_oauth_access_token = var.zendesk_oauth_access_token

  # Pass IAM role name variables
  iam_role_lambda_authorizer_name           = var.iam_role_lambda_authorizer_name
  iam_role_lambda_support_case_monitor_name = var.iam_role_lambda_support_case_monitor_name
  iam_role_lambda_webhook_listener_name     = var.iam_role_lambda_webhook_listener_name
}

module "storage" {
  # Import storage module
  source = "./modules/storage"

  # Pass required variables
  kms_key_arn = module.security.kms_key_arn

  # Pass IAM role name variables
  iam_role_lambda_authorizer_name           = var.iam_role_lambda_authorizer_name
  iam_role_lambda_support_case_monitor_name = var.iam_role_lambda_support_case_monitor_name
}

module "queues" {
  # Import queues module
  source = "./modules/queues"

  # Pass required variables
  kms_key_arn = module.security.kms_key_arn
}


module "lambda" {
  # Import Lambda module
  source = "./modules/lambda"

  # Pass required variables
  region                         = var.region
  zendesk_subdomain              = var.zendesk_subdomain
  zendesk_admin_email            = var.zendesk_admin_email
  api_key_arn                    = module.security.api_key_arn
  zendesk_oauth_access_token_arn = module.security.zendesk_oauth_access_token_arn
  dynamodb_lookup_table_arn      = module.storage.dynamodb_lookup_table_arn
  sqs_dlq_arn                    = module.queues.sqs_dlq_arn
  kms_key_arn                    = module.security.kms_key_arn

  # Pass IAM role name variables
  iam_role_lambda_authorizer_name           = var.iam_role_lambda_authorizer_name
  iam_role_lambda_support_case_monitor_name = var.iam_role_lambda_support_case_monitor_name
  iam_role_lambda_webhook_listener_name     = var.iam_role_lambda_webhook_listener_name
}

module "api" {
  # Import API module
  source = "./modules/api"

  # Pass required variables
  lambda_authorizer_arn        = module.lambda.lambda_authorizer_arn
  lambda_authorizer_invoke_arn = module.lambda.lambda_authorizer_invoke_arn
}


module "events" {
  # Import Events module
  source = "./modules/events"

  # Pass required variables
  lambda_webhook_listener_arn     = module.lambda.lambda_webhook_listener_arn
  lambda_support_case_monitor_arn = module.lambda.lambda_support_case_monitor_arn
}

# Output important information
output "zendesk_aws_connector_output" {
  description = "Information about the deployed Zendesk AWS Support Connector"
  value = {
    region            = var.region
    zendesk_subdomain = var.zendesk_subdomain
    api_gateway_url   = module.api.api_gateway_url
  }
}

output "api_gateway_url" {
  description = "API Gateway URL"
  value       = module.api.api_gateway_url

}