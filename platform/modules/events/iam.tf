# EventBridge - Allow Lambda webhook function invocation
resource "aws_lambda_permission" "eventbridge_lambda_webhook_listener" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = split(":", var.lambda_webhook_listener_arn)[6]
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.event_listener_rule.arn
}

# EventBridge - Lambda Support API function invocation
resource "aws_lambda_permission" "eventbridge_lambda_support_case_monitor" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = split(":", var.lambda_support_case_monitor_arn)[6]
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.support_case_rule.arn
}
