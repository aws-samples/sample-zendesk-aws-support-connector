
resource "aws_secretsmanager_secret" "api_key" {
  name                    = "zendesk_api_gateway_key"
  description             = "Zendesk - API gateway API Key."
  kms_key_id              = aws_kms_key.dynamo.arn
  recovery_window_in_days = 0
}



resource "aws_secretsmanager_secret_version" "gateway_secret_version" {
  secret_id      = aws_secretsmanager_secret.api_key.id
  secret_string  = var.bearer_token
  version_stages = ["AWSCURRENT"]
}