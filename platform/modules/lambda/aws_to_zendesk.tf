# AWS to Zendesk - CloudWatch log group for Lambda
resource "aws_cloudwatch_log_group" "log_group_lambda_support_case_monitor" {
  name              = "/aws/lambda/aws_to_zendesk"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn
}

# AWS to Zendesk - Lambda Function
resource "aws_lambda_function" "lambda_support_case_monitor" {
  function_name                  = "aws_to_zendesk"
  role                           = aws_iam_role.iam_role_lambda_support_case_monitor.arn
  runtime                        = "python3.13"
  handler                        = "handler.lambda_handler"
  filename                       = "${path.root}/../dist/aws_to_zendesk.zip"
  source_code_hash               = filebase64sha256("${path.root}/../dist/aws_to_zendesk.zip")
  timeout                        = 15
  reserved_concurrent_executions = 3
  kms_key_arn                    = var.kms_key_arn

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      EVENT_BUS_ARN       = data.aws_cloudwatch_event_bus.default.arn
      ZENDESK_SUBDOMAIN   = var.zendesk_subdomain
      ZENDESK_ADMIN_EMAIL = var.zendesk_admin_email
      TABLE_NAME          = split("/", var.dynamodb_lookup_table_arn)[1]
      REGION_NAME         = var.region
    }
  }

  dead_letter_config {
    target_arn = var.sqs_dlq_arn
  }
}
