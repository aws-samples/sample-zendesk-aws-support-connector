data "aws_cloudwatch_event_bus" "default" {
  name = "default"
}

resource "aws_iam_policy" "secretsmanager_zendesk_read_policy" {
  name        = "zendesk_secretsmanager_read_policy"
  description = "IAM policy for retrieving Zendesk API key from Secrets Manager"
  policy = templatefile("${path.root}/policies/secretsmanager_read_policy.template.json", {
    secret_arn = var.zendesk_oauth_access_token_arn
  })
}

resource "aws_iam_policy" "secretsmanager_apigateway_read_policy" {
  name        = "zendesk_secretsmanager_apigateway_read_policy"
  description = "IAM policy for retrieving API Gateway key from Secrets Manager"
  policy = templatefile("${path.root}/policies/secretsmanager_read_policy.template.json", {
    secret_arn = var.api_key_arn
  })
}

resource "aws_iam_policy" "xray_readwrite_policy" {
  name        = "zendesk_xray_readwrite_policy"
  description = "IAM policy for X-Ray tracing"
  policy      = file("${path.root}/policies/xray_readwrite_policy.json")
}

resource "aws_iam_policy" "sqs_dlq_write_policy" {
  name = "zendesk_sqs_dlq_write_policy"
  description = "IAM policy for SQS write (Lambda DLQ)"
  policy = templatefile("${path.root}/policies/sqs_write_policy.template.json", {
    queue_arn = var.sqs_dlq_arn
  })
}

resource "aws_iam_policy" "eventbridge_default_bus_read_policy" {
  name        = "zendesk_eventbridge_default_bus_read_policy"
  description = "IAM policy for retrieving events from EventBridge"
  policy = templatefile("${path.root}/policies/eventbridge_read_policy.template.json", {
    event_bus_arn = data.aws_cloudwatch_event_bus.default.arn
  })
}

resource "aws_iam_policy" "dynamodb_lookup_table_readwrite_policy" {
  name        = "zendesk_dynamodb_lookup_table_readwrite_policy"
  description = "IAM policy for DynamoDB lookup table read-write access"
  policy = templatefile("${path.root}/policies/dynamodb_readwrite_policy.template.json", {
    table_arn = var.dynamodb_lookup_table_arn
  })
}

resource "aws_iam_policy" "supportapi_readwrite_policy" {
  name        = "zendesk_supportapi_readwrite_policy"
  description = "Policy to edit support cases"
  policy      = file("${path.root}/policies/supportapi_readwrite_policy.json")
}


# Lambda Authorizer - IAM role
resource "aws_iam_role" "iam_role_lambda_authorizer" {
  name = var.iam_role_lambda_authorizer_name
  assume_role_policy = file("${path.root}/policies/lambda_trust_policy.json")
}

# Lambda Authorizer - IAM policies
resource "aws_iam_role_policy_attachment" "lambda_authorizer_secretsmanager" {
  role       = aws_iam_role.iam_role_lambda_authorizer.name
  policy_arn = aws_iam_policy.secretsmanager_zendesk_read_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_authorizer_xray" {
  role       = aws_iam_role.iam_role_lambda_authorizer.name
  policy_arn = aws_iam_policy.xray_readwrite_policy.arn
}
resource "aws_iam_role_policy_attachment" "lambda_authorizer_sqs" {
  role       = aws_iam_role.iam_role_lambda_authorizer.name
  policy_arn = aws_iam_policy.sqs_dlq_write_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_authorizer_basic_execution" {
  role       = aws_iam_role.iam_role_lambda_authorizer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# Lambda Support API - IAM role
resource "aws_iam_role" "iam_role_lambda_support_case_monitor" {
  name = var.iam_role_lambda_support_case_monitor_name
  assume_role_policy = file("${path.root}/policies/lambda_trust_policy.json")
}

# Lambda Support API - IAM policies
resource "aws_iam_role_policy_attachment" "lambda_support_sqs" {
  role       = aws_iam_role.iam_role_lambda_support_case_monitor.name
  policy_arn = aws_iam_policy.sqs_dlq_write_policy.arn
}
resource "aws_iam_role_policy_attachment" "lambda_support_dynamodb" {
  role       = aws_iam_role.iam_role_lambda_support_case_monitor.name
  policy_arn = aws_iam_policy.dynamodb_lookup_table_readwrite_policy.arn
}
resource "aws_iam_role_policy_attachment" "lambda_support_eventbridge" {
  role       = aws_iam_role.iam_role_lambda_support_case_monitor.name
  policy_arn = aws_iam_policy.eventbridge_default_bus_read_policy.arn
}
resource "aws_iam_role_policy_attachment" "lambda_support_secretsmanager" {
  role       = aws_iam_role.iam_role_lambda_support_case_monitor.name
  policy_arn = aws_iam_policy.secretsmanager_apigateway_read_policy.arn
}
resource "aws_iam_role_policy_attachment" "lambda_support_supportapi" {
  role       = aws_iam_role.iam_role_lambda_support_case_monitor.name
  policy_arn = aws_iam_policy.supportapi_readwrite_policy.arn
}
resource "aws_iam_role_policy_attachment" "lambda_support_basic_execution" {
  role       = aws_iam_role.iam_role_lambda_support_case_monitor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# Lambda Webhook Listener - IAM role
resource "aws_iam_role" "iam_role_lambda_webhook_listener" {
  name               = var.iam_role_lambda_webhook_listener_name
  assume_role_policy = file("${path.root}/policies/lambda_trust_policy.json")
}

# Lambda Event Listener - IAM policies
resource "aws_iam_role_policy_attachment" "lambda_webhook_listener_sqs" {
  role       = aws_iam_role.iam_role_lambda_webhook_listener.name
  policy_arn = aws_iam_policy.sqs_dlq_write_policy.arn
}
resource "aws_iam_role_policy_attachment" "lambda_webhook_listener_dynamodb" {
  role       = aws_iam_role.iam_role_lambda_webhook_listener.name
  policy_arn = aws_iam_policy.dynamodb_lookup_table_readwrite_policy.arn
}
resource "aws_iam_role_policy_attachment" "lambda_webhook_listener_eventbridge" {
  role       = aws_iam_role.iam_role_lambda_webhook_listener.name
  policy_arn = aws_iam_policy.eventbridge_default_bus_read_policy.arn
}
resource "aws_iam_role_policy_attachment" "lambda_webhook_listener_xray" {
  role       = aws_iam_role.iam_role_lambda_webhook_listener.name
  policy_arn = aws_iam_policy.xray_readwrite_policy.arn
}
resource "aws_iam_role_policy_attachment" "lambda_webhook_listener_supportapi" {
  role       = aws_iam_role.iam_role_lambda_webhook_listener.name
  policy_arn = aws_iam_policy.supportapi_readwrite_policy.arn
}
resource "aws_iam_role_policy_attachment" "lambda_basic_execution_listener" {
  role       = aws_iam_role.iam_role_lambda_webhook_listener.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}