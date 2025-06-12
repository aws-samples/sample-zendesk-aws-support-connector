variable "region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "zendesk_subdomain" {
  description = "Zendesk subdomain"
  type        = string
}

variable "zendesk_admin_email" {
  description = "Zendesk admin email linked to the API key"
  type        = string
}

variable "zendesk_oauth_access_token_arn" {
  description = "ARN of the Zendesk OAuth access token secret"
  type        = string
}

variable "api_key_arn" {
  description = "ARN of the API key secret"
  type        = string
}

variable "dynamodb_lookup_table_arn" {
  description = "ARN of the DynamoDB ID lookup table"
  type        = string
}

variable "sqs_dlq_arn" {
  description = "ARN of the SQS queue for Lambda DLQ"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "iam_role_lambda_support_case_monitor_name" {
  description = "Name for the IAM role used by the support case monitor Lambda function"
  type        = string
}

variable "iam_role_lambda_authorizer_name" {
  description = "Name for the IAM role used by the authorizer Lambda function"
  type        = string
}

variable "iam_role_lambda_webhook_listener_name" {
  description = "Name for the IAM role used by the webhook listener Lambda function"
  type        = string
}
