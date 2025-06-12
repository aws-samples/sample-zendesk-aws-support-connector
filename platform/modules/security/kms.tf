resource "aws_kms_key" "encryption_key" {
  description             = "KMS key for resource encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = templatefile("${path.root}/policies/kms_policy.template.json", {
    account_id      = data.aws_caller_identity.current.account_id
    region          = var.region
    role_names = [
      var.iam_role_lambda_authorizer_name,
      var.iam_role_lambda_support_case_monitor_name,
      var.iam_role_lambda_webhook_listener_name
    ]
  })
}

