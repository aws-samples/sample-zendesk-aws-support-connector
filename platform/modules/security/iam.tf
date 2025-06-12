data "aws_caller_identity" "current" {}

# Secret Manager - API key policy
resource "aws_secretsmanager_secret_policy" "secretsmanager_api_key_policy" {
  secret_arn = aws_secretsmanager_secret.secretsmanager_api_key.arn
  policy = templatefile("${path.root}/policies/secretsmanager_resource_policy.template.json", {
    account_id  = data.aws_caller_identity.current.account_id
    role_name   = var.iam_role_lambda_authorizer_name
    secret_arn  = aws_secretsmanager_secret.secretsmanager_api_key.arn
  })
}

# Secret Manager - Zendesk OAuth token policy
resource "aws_secretsmanager_secret_policy" "secretsmanager_zendesk_token_policy" {
  secret_arn = aws_secretsmanager_secret.secretsmanager_zendesk_token.arn
  policy = templatefile("${path.root}/policies/secretsmanager_resource_policy.template.json", {
    account_id  = data.aws_caller_identity.current.account_id
    role_name   = var.iam_role_lambda_support_case_monitor_name
    secret_arn  = aws_secretsmanager_secret.secretsmanager_zendesk_token.arn
  })
}

