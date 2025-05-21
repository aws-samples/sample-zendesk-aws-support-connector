resource "aws_secretsmanager_secret" "zendesk_oauth_access_token" {
  name        = "zendesk_oauth_access_token"
  description = "External Zendesk API key"
  kms_key_id  = aws_kms_key.dynamo.arn
}

resource "aws_secretsmanager_secret_version" "zendesk_secret_version" {
  secret_id      = aws_secretsmanager_secret.zendesk_oauth_access_token.id
  secret_string  = var.zendesk_oauth_access_token
  version_stages = ["AWSCURRENT"]

}
