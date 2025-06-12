
resource "aws_secretsmanager_secret" "secretsmanager_api_key" {
  name                    = "zendesk_api_gateway_key"
  description             = "Zendesk - API gateway API Key."
  kms_key_id              = aws_kms_key.encryption_key.arn
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "secretsmanager_api_key_version" {
  secret_id      = aws_secretsmanager_secret.secretsmanager_api_key.id
  secret_string  = var.bearer_token
  version_stages = ["AWSCURRENT"]
}