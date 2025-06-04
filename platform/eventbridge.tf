data "aws_cloudwatch_event_bus" "default" {
  name = "default"
}
# EventBridge Rule pour déclencher la Lambda
resource "aws_cloudwatch_event_rule" "event_listener_rule" {
  name           = "event_listener_rule"
  description    = "Déclenche la Lambda lorsqu'un événement arrive dans EventBridge"
  event_bus_name = data.aws_cloudwatch_event_bus.default.name

  event_pattern = <<EOF
{
  "source": ["zendesk.webhook"]
}
EOF
}

# Permission pour EventBridge d'invoquer la Lambda
resource "aws_lambda_permission" "allow_eventbridge_invoke" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.event_listener_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.event_listener_rule.arn
}

# Associer la règle EventBridge à la Lambda
resource "aws_cloudwatch_event_target" "event_listener_target" {
  rule           = aws_cloudwatch_event_rule.event_listener_rule.name
  target_id      = "event-listener"
  arn            = aws_lambda_function.event_listener_lambda.arn
  event_bus_name = data.aws_cloudwatch_event_bus.default.name
}

# EventBridge Rule to trigger Lambda on AWS Support Case events
resource "aws_cloudwatch_event_rule" "support_case_rule" {
  name           = "support_case_rule"
  description    = "Triggers when an AWS support case event occurs"
  event_bus_name = "default"
  event_pattern = jsonencode({
    source = [
      "aws.support"
    ]
  })
}

# Allow EventBridge to invoke the Lambda function
resource "aws_lambda_permission" "allow_eventbridge_support_case" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.support_case_monitor_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.support_case_rule.arn
}

# Attach EventBridge Rule to Lambda
resource "aws_cloudwatch_event_target" "support_case_target" {
  rule           = aws_cloudwatch_event_rule.support_case_rule.name
  target_id      = "support-case-listener"
  arn            = aws_lambda_function.support_case_monitor_lambda.arn
  event_bus_name = "default"
}


