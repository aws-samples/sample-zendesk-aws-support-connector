resource "aws_secretsmanager_secret" "secretsmanager_zendesk_token" {
  name                    = "zendesk_oauth_access_token"
  description             = "External Zendesk API key"
  kms_key_id              = aws_kms_key.encryption_key.arn
  recovery_window_in_days = 0

}

resource "aws_secretsmanager_secret_version" "secretsmanager_zendesk_token_version" {
  secret_id      = aws_secretsmanager_secret.secretsmanager_zendesk_token.id
  secret_string  = var.zendesk_oauth_access_token
  version_stages = ["AWSCURRENT"]

}
