data "aws_caller_identity" "current" {}

# DynamoDB - Resource based policy
resource "aws_dynamodb_resource_policy" "acces_from_lambda_policy" {
  resource_arn = aws_dynamodb_table.dynamodb_lookup_table.arn

  policy = templatefile("${path.root}/policies/dynamodb_rbac.template.json", {
    lookup_table_arn   = aws_dynamodb_table.dynamodb_lookup_table.arn
    account_id         = data.aws_caller_identity.current.account_id
    role_names  = [
      var.iam_role_lambda_authorizer_name,
      var.iam_role_lambda_support_case_monitor_name
    ]
  })
}