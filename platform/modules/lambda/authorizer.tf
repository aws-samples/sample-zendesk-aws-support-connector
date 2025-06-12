# Authorizer - CloudWatch Log Group
resource "aws_cloudwatch_log_group" "log_group_lambda_authorizer" {
  name              = "/aws/lambda/zendesk_authorizer"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn
}

# Authorizer - Lambda function
resource "aws_lambda_function" "lambda_authorizer" {
  function_name                  = "zendesk_authorizer"
  role                           = aws_iam_role.iam_role_lambda_authorizer.arn
  runtime                        = "python3.13"
  handler                        = "handler.lambda_handler"
  filename                       = "${path.root}/../dist/api_authorizer.zip"
  source_code_hash               = filebase64sha256("${path.root}/../dist/api_authorizer.zip")
  timeout                        = 15
  reserved_concurrent_executions = 3
  kms_key_arn                    = var.kms_key_arn
  
  tracing_config {
    mode = "Active"
  }
  
  environment {
    variables = {
      REGION_NAME = var.region
    }
  }
  dead_letter_config {
    target_arn = var.sqs_dlq_arn
  }
}