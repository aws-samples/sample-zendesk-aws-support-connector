output "lambda_authorizer_arn" {
  description = "ARN of the Lambda Authorizer function"
  value       = aws_lambda_function.lambda_authorizer.arn
}

output "lambda_authorizer_invoke_arn" {
  description = "ARN of the Lambda Authorizer function for API Gateway invocation"
  value       = aws_lambda_function.lambda_authorizer.invoke_arn
}

output "lambda_support_case_monitor_arn" {
  description = "ARN of the Lambda Support Case Monitor function"
  value       = aws_lambda_function.lambda_support_case_monitor.arn
}

output "lambda_webhook_listener_arn" {
  description = "ARN of the Lambda Webhook Listener function"
  value       = aws_lambda_function.lambda_webhook_listener.arn
}