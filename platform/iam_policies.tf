resource "aws_iam_policy" "logging_tracing_policy" {
  name        = "logging_tracing_policy"
  description = "Policy for logging_tracing XRAY"
  policy      = file("${path.module}/policies/logging_tracing_policy.json")
}

resource "aws_iam_policy" "get_zd_secret_policy" {
  name        = "get_zd_secret_policy"
  description = "Policy for retrieving Zendesk secrets from SM"
  policy = templatefile("${path.module}/policies/get_zd_secret_policy.tpl.json", {
    zendesk_secret_arn = aws_secretsmanager_secret.zendesk_oauth_access_token.arn
  })
}

resource "aws_iam_policy" "get_api_secret_policy" {
  name        = "get_api_secret_policy"
  description = "Policy for retrieving API secrets from SM"
  policy = templatefile("${path.module}/policies/get_api_secret_policy.tpl.json", {
    api_secret_arn = aws_secretsmanager_secret.api_key.arn
  })
}

resource "aws_iam_policy" "default_bus_access_policy" {
  name        = "default_bus_access_policy"
  description = "Policy for retrieving Events"
  policy = templatefile("${path.module}/policies/default_bus_access_policy.tpl.json", {
    default_bus_arn = "arn:aws:events:${var.region}:${data.aws_caller_identity.current.account_id}:event-bus/default"
  })
}

resource "aws_iam_policy" "webhook_bus_access_policy" {
  name        = "webhook_bus_access_policy"
  description = "Policy for webhook event bus access"
  policy = templatefile("${path.module}/policies/webhook_bus_access_policy.tpl.json", {
    webhook_bus_arn = aws_cloudwatch_event_bus.webhook_event_bus.arn
  })
}

resource "aws_iam_policy" "lookup_db_policy" {
  name        = "lookup_db_policy"
  description = "Policy for lookup_db"
  policy = templatefile("${path.module}/policies/lookup_db_policy.tpl.json", {
    lookup_table_arn = aws_dynamodb_table.idlookup.arn
  })
}

resource "aws_iam_policy" "edit_support_cases" {
  name        = "edit_support_cases"
  description = "Policy to edit support cases"
  policy      = file("${path.module}/policies/edit_support_cases.json")
}


# DYNAMODB Resource based policy
resource "aws_dynamodb_resource_policy" "acces_from_lambda_policy" {
  resource_arn = aws_dynamodb_table.idlookup.arn

  policy = templatefile("${path.module}/policies/dynamo_rbac.tpl.json", {
    lookup_table_arn   = aws_dynamodb_table.idlookup.arn
    account_id         = data.aws_caller_identity.current.account_id
    lambda_role_name_1 = aws_iam_role.lambda_support_case_role.name
    lambda_role_name_2 = aws_iam_role.lambda_event_listener_role.name
  })
}

# Secret Manager policies



resource "aws_secretsmanager_secret_policy" "api_gateway_secret_policy" {
  secret_arn = aws_secretsmanager_secret.api_key.arn
  policy = templatefile("${path.module}/policies/api_secretsmanager_policy.tpl.json", {
    lookup_table_arn = aws_dynamodb_table.idlookup.arn
    account_id       = data.aws_caller_identity.current.account_id
    authorizer_role  = aws_lambda_function.authorizer.role
    resources        = aws_secretsmanager_secret.api_key.arn
  })
}
resource "aws_secretsmanager_secret_policy" "zendesk_gateway_secret_policy" {
  secret_arn = aws_secretsmanager_secret.zendesk_oauth_access_token.arn
  policy = templatefile("${path.module}/policies/api_secretsmanager_policy.tpl.json", {
    lookup_table_arn = aws_dynamodb_table.idlookup.arn
    account_id       = data.aws_caller_identity.current.account_id
    authorizer_role  = aws_lambda_function.support_case_monitor_lambda.role
    resources        = aws_secretsmanager_secret.zendesk_oauth_access_token.arn
  })
}

resource "aws_iam_policy" "lambda_dlq_policy" {
  name = "zendesk_to_aws_dlq_policy"
  policy = templatefile("${path.module}/policies/dlq_policy.tpl.json", {
    sqs_dlq_arn = aws_sqs_queue.lambda_dlq.arn
  })
}