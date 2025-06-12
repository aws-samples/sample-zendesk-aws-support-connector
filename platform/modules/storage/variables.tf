variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
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