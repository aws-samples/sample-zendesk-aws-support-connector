resource "aws_dynamodb_table" "dynamodb_lookup_table" {
  name         = "zendesk_lookup_table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id-z"
  attribute {
    name = "id-z"
    type = "S"
  }
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }
  point_in_time_recovery {
    enabled = true
  }
  tags = {
    Name = "zendesk-lookup-table"
  }
}

