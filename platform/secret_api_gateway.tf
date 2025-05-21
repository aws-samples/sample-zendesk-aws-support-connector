
resource "aws_secretsmanager_secret" "api_key" {
  name                    = "api_key"
  description             = "API gateway API key"
  kms_key_id              = aws_kms_key.dynamo.arn
  recovery_window_in_days = 0
}



resource "aws_secretsmanager_secret_version" "gateway_secret_version" {
  secret_id      = aws_secretsmanager_secret.api_key.id
  secret_string  = var.bearer_token
  version_stages = ["AWSCURRENT"]
}