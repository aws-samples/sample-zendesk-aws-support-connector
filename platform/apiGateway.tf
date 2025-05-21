resource "aws_apigatewayv2_api" "webhook_api" {
  name          = "zendesk_webhook_api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "eventbridge_integration_create" {
  api_id              = aws_apigatewayv2_api.webhook_api.id
  integration_type    = "AWS_PROXY"
  integration_subtype = "EventBridge-PutEvents"
  request_parameters = {
    EventBusName = aws_cloudwatch_event_bus.webhook_event_bus.name
    Detail       = "$request.body"
    DetailType   = "create.webhook"
    Source       = "zendesk.webhook"
  }
  credentials_arn        = aws_iam_role.apigateway_eventbridge_role.arn
  payload_format_version = "1.0"
}
resource "aws_apigatewayv2_integration" "eventbridge_integration_solved" {
  api_id              = aws_apigatewayv2_api.webhook_api.id
  integration_type    = "AWS_PROXY"
  integration_subtype = "EventBridge-PutEvents"
  request_parameters = {
    EventBusName = aws_cloudwatch_event_bus.webhook_event_bus.name
    Detail       = "$request.body"
    DetailType   = "solved.webhook"
    Source       = "zendesk.webhook"
  }
  credentials_arn        = aws_iam_role.apigateway_eventbridge_role.arn
  payload_format_version = "1.0"
}
resource "aws_apigatewayv2_integration" "eventbridge_integration_update" {
  api_id              = aws_apigatewayv2_api.webhook_api.id
  integration_type    = "AWS_PROXY"
  integration_subtype = "EventBridge-PutEvents"
  request_parameters = {
    EventBusName = aws_cloudwatch_event_bus.webhook_event_bus.name
    Detail       = "$request.body"
    DetailType   = "update.webhook"
    Source       = "zendesk.webhook"
  }
  credentials_arn        = aws_iam_role.apigateway_eventbridge_role.arn
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_route" "webhook_route_create" {
  api_id             = aws_apigatewayv2_api.webhook_api.id
  route_key          = "POST /create"
  target             = "integrations/${aws_apigatewayv2_integration.eventbridge_integration_create.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.hmac_auth.id
  authorization_type = "CUSTOM"
}
resource "aws_apigatewayv2_route" "webhook_route_update" {
  api_id             = aws_apigatewayv2_api.webhook_api.id
  route_key          = "POST /update"
  target             = "integrations/${aws_apigatewayv2_integration.eventbridge_integration_update.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.hmac_auth.id
  authorization_type = "CUSTOM"
}
resource "aws_apigatewayv2_route" "webhook_route_solved" {
  api_id             = aws_apigatewayv2_api.webhook_api.id
  route_key          = "POST /solved"
  target             = "integrations/${aws_apigatewayv2_integration.eventbridge_integration_solved.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.hmac_auth.id
  authorization_type = "CUSTOM"
}

resource "aws_apigatewayv2_stage" "webhook_stage" {
  api_id      = aws_apigatewayv2_api.webhook_api.id
  name        = "production"
  auto_deploy = true
  description = "stage1"
}


resource "aws_cloudwatch_log_group" "apigwlg" {
  name              = "/aws/apigateway/webhook"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.dynamo.arn
  tags = {
    Name = "zendesk-webhook-logs"
  }
}


resource "aws_iam_role" "apigateway_eventbridge_role" {
  name = "apigateway_eventbridge_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "apigateway_eventbridge_policy" {
  name        = "apigateway_eventbridge_policy"
  description = "Allow API Gateway to send events to EventBridge"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "events:PutEvents"
      ],
      "Resource": "${aws_cloudwatch_event_bus.webhook_event_bus.arn}"
    }
  ]
}
EOF
}

resource "aws_lambda_permission" "api_gateway_invoke_auth" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.webhook_api.execution_arn}/*"
}

resource "aws_iam_role_policy_attachment" "apigateway_eventbridge_attach" {
  role       = aws_iam_role.apigateway_eventbridge_role.name
  policy_arn = aws_iam_policy.apigateway_eventbridge_policy.arn
}

output "api_gateway_url" {
  value = aws_apigatewayv2_stage.webhook_stage.invoke_url
}