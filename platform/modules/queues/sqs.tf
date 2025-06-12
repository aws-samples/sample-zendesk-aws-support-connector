resource "aws_sqs_queue" "sqs_dlq" {
  name                              = "zendesk_sqs_dlq"
  kms_master_key_id                 = var.kms_key_arn
  kms_data_key_reuse_period_seconds = 300
}