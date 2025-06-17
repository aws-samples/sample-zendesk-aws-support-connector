// log group for API access logs 
resource "aws_cloudwatch_log_group" "api_access_logs" {
  name              = "/aws/apigateway/zd-access-logs"
  retention_in_days = 14
  tags = {
    Name = "zd-access-logs"
  }
}

