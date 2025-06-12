data "aws_cloudwatch_event_bus" "default" {
  name = "default"
}

resource "aws_iam_role" "apigateway_eventbridge_role" {
  name = "zendesk_apigateway_eventbridge_role"

  assume_role_policy = file("${path.root}/policies/apigateway_trust_policy.json")
}

resource "aws_iam_policy" "apigateway_eventbridge_policy" {
  name        = "zendesk_apigateway_eventbridge_policy"
  description = "Allow API Gateway to send events to EventBridge"

  policy = templatefile("${path.root}/policies/apigateway_policy.template.json", {
    event_bus_arn = data.aws_cloudwatch_event_bus.default.arn
  })
}

resource "aws_iam_role_policy_attachment" "apigateway_eventbridge_attach" {
  role       = aws_iam_role.apigateway_eventbridge_role.name
  policy_arn = aws_iam_policy.apigateway_eventbridge_policy.arn
}

resource "aws_lambda_permission" "api_gateway_invoke_auth" {
  action        = "lambda:InvokeFunction"
  function_name = split(":", var.lambda_authorizer_arn)[6]
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.webhook_api.execution_arn}/*"
}
