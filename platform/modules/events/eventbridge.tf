data "aws_cloudwatch_event_bus" "default" {
  name = "default"
}

# EventBridge - Lambda webhook listener function rule
resource "aws_cloudwatch_event_rule" "event_listener_rule" {
  name           = "event_listener_rule"
  description    = "EventBridge - Rule for Lambda functions triggering from Zendesk Webhook"
  event_bus_name = data.aws_cloudwatch_event_bus.default.name

  event_pattern = jsonencode({
    source = ["zendesk.webhook"]
  })
}

# Eventbridge - Lambda webhook listener function target
resource "aws_cloudwatch_event_target" "event_listener_target" {
  rule           = aws_cloudwatch_event_rule.event_listener_rule.name
  target_id      = "event-listener"
  arn            = var.lambda_webhook_listener_arn
  event_bus_name = data.aws_cloudwatch_event_bus.default.name
}

# EventBridge - Lambda support case monitoring rule
resource "aws_cloudwatch_event_rule" "support_case_rule" {
  name           = "support_case_rule"
  description    = "Triggers when an AWS support case event occurs"
  event_bus_name = "default"
  event_pattern = jsonencode({
    source = ["aws.support"]
  })
}

# EventBridge - Lambda support case monitoring target
resource "aws_cloudwatch_event_target" "support_case_target" {
  rule           = aws_cloudwatch_event_rule.support_case_rule.name
  target_id      = "support-case-listener"
  arn            = var.lambda_support_case_monitor_arn
  event_bus_name = "default"
}


