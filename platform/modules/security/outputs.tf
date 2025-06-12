output "zendesk_oauth_access_token_arn" {
  description = "ARN of the Zendesk OAuth access token secret"
  value       = aws_secretsmanager_secret.secretsmanager_zendesk_token.arn
}

output "api_key_arn" {
  description = "ARN of the API key secret"
  value       = aws_secretsmanager_secret.secretsmanager_api_key.arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key"
  value       = aws_kms_key.encryption_key.arn
}
