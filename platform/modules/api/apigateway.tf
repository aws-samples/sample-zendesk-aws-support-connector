resource "aws_apigatewayv2_api" "webhook_api" {
  name          = "zendesk_webhook_api"
  protocol_type = "HTTP"
}

# APIGW v2 Authorizer
resource "aws_apigatewayv2_authorizer" "hmac_auth" {
  api_id                            = aws_apigatewayv2_api.webhook_api.id
  name                              = "zendesk_authorizer"
  authorizer_type                   = "REQUEST"
  authorizer_payload_format_version = "2.0"
  authorizer_uri                    = var.lambda_authorizer_invoke_arn
  identity_sources                  = ["$request.header.Authorization"]
  enable_simple_responses           = true
}

resource "aws_apigatewayv2_integration" "eventbridge_integration_create" {
  api_id              = aws_apigatewayv2_api.webhook_api.id
  integration_type    = "AWS_PROXY"
  integration_subtype = "EventBridge-PutEvents"
  request_parameters = {
    EventBusName = data.aws_cloudwatch_event_bus.default.name
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
    EventBusName = data.aws_cloudwatch_event_bus.default.name
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
    EventBusName = data.aws_cloudwatch_event_bus.default.name
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
  description = "Zendesk Webhook - Production Stage"
  default_route_settings {
    throttling_rate_limit  = 100
    throttling_burst_limit = 50
    logging_level = "INFO"
    detailed_metrics_enabled = true
    data_trace_enabled = true
  }
access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access_logs.arn
    format = jsonencode({
      requestId       = "$context.requestId"
      sourceIp        = "$context.identity.sourceIp"
      requestTime     = "$context.requestTime"
      httpMethod      = "$context.httpMethod"
      routeKey        = "$context.routeKey"
      status          = "$context.status"
      protocol        = "$context.protocol"
      responseLength  = "$context.responseLength"
    })
  }
}