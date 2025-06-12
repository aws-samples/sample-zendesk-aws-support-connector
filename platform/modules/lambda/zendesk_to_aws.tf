# Lambda - CloudWatch Log Group
resource "aws_cloudwatch_log_group" "log_group_lambda_webhook_listener" {
  name              = "/aws/lambda/zendesk_to_aws"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn
}

# Lambda - Function Definition
resource "aws_lambda_function" "lambda_webhook_listener" {
  function_name                  = "zendesk_to_aws"
  role                           = aws_iam_role.iam_role_lambda_webhook_listener.arn
  runtime                        = "python3.13"
  handler                        = "handler.lambda_handler"
  filename                       = "${path.root}/../dist/zendesk_to_aws.zip"
  source_code_hash               = filebase64sha256("${path.root}/../dist/zendesk_to_aws.zip")
  timeout                        = 15
  reserved_concurrent_executions = 3
  kms_key_arn = var.kms_key_arn

  tracing_config {
    mode = "Active"
  }
  environment {
    variables = {
      EVENT_BUS_ARN = data.aws_cloudwatch_event_bus.default.arn
      TABLE_NAME    = split("/", var.dynamodb_lookup_table_arn)[1]
    }
  }
  
  dead_letter_config {
    target_arn = var.sqs_dlq_arn
  }
}

