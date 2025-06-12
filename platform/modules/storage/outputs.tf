output "dynamodb_lookup_table_arn" {
  description = "ARN of the DynamoDB ID lookup table"
  value       = aws_dynamodb_table.dynamodb_lookup_table.arn
}