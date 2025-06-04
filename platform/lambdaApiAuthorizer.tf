resource "aws_lambda_function" "authorizer" {
  function_name                  = "ApiAuthorizer"
  role                           = aws_iam_role.lambda_authorizer_role.arn
  runtime                        = "python3.13"
  handler                        = "handler.lambda_handler"
  filename                       = "${path.module}/../dist/api_authorizer.zip"
  source_code_hash               = filebase64sha256("${path.module}/../dist/api_authorizer.zip")
  timeout                        = 15
  reserved_concurrent_executions = 3
  tracing_config {
    mode = "Active"
  }
  environment {
    variables = {
      REGION_NAME = var.region

    }
  }
  kms_key_arn = aws_kms_key.dynamo.arn
  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }
}

resource "aws_apigatewayv2_authorizer" "hmac_auth" {
  api_id                            = aws_apigatewayv2_api.webhook_api.id
  name                              = "ApiAuthorizer"
  authorizer_type                   = "REQUEST"
  authorizer_payload_format_version = "2.0"
  authorizer_uri                    = aws_lambda_function.authorizer.invoke_arn
  identity_sources                  = ["$request.header.Authorization"]
  enable_simple_responses           = true
}

resource "aws_cloudwatch_log_group" "lambda_authorizer_log" {
  name              = "/aws/lambda/ApiAuthorizer"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.dynamo.arn
}


// Lambda authorizer role 
resource "aws_iam_role" "lambda_authorizer_role" {
  name = "lambda_authorizer_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "lambda_attach_secrets" {
  role       = aws_iam_role.lambda_authorizer_role.name
  policy_arn = aws_iam_policy.get_zd_secret_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_attach_logging" {
  role       = aws_iam_role.lambda_authorizer_role.name
  policy_arn = aws_iam_policy.logging_tracing_policy.arn
}
resource "aws_iam_role_policy_attachment" "lambda_dlq_policy_attach" {
  role       = aws_iam_role.lambda_authorizer_role.name
  policy_arn = aws_iam_policy.lambda_dlq_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_authorizer_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}