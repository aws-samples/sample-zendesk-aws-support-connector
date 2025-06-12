output "sqs_dlq_arn" {
  description = "ARN of the SQS queue for Lambda DLQ"
  value       = aws_sqs_queue.sqs_dlq.arn
}