variable "lambda_authorizer_arn" {
  description = "ARN of the Lambda Authorizer function"
  type        = string
}

variable "lambda_authorizer_invoke_arn" {
  description = "ARN of the Lambda Authorizer function for API Gateway invocation"
  type        = string
}