variable "region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "bearer_token" {
  description = "Bearer token to be used by Zendesk webhooks"
  type        = string
}

variable "zendesk_oauth_access_token" {
  description = "Zendesk API key"
  type        = string
}

variable "iam_role_lambda_authorizer_name" {
  description = "Name for the IAM role used by the authorizer Lambda function"
  type        = string
}

variable "iam_role_lambda_support_case_monitor_name" {
  description = "Name for the IAM role used by the support case monitor Lambda function"
  type        = string
}

variable "iam_role_lambda_webhook_listener_name" {
  description = "Name for the IAM role used by the webhook listener Lambda function"
  type        = string
}