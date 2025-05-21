resource "aws_sqs_queue" "lambda_dlq" {
  name                              = "zendesk-to-aws-dlq"
  kms_master_key_id                 = aws_kms_key.dynamo.arn
  kms_data_key_reuse_period_seconds = 300
}