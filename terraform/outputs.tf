# Output values
output "raw_uploads_bucket" {
  value = aws_s3_bucket.raw_uploads.bucket
}

output "processed_bucket" {
  value = aws_s3_bucket.processed.bucket
}

output "dynamodb_table" {
  value = aws_dynamodb_table.jobs.name
}

output "sqs_queue_url" {
  value = aws_sqs_queue.processing.url
}

output "api_url" {
  description = "Base URL for the CloudSnap API"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "cloudwatch_dashboard_url" {
  description = "Direct link to the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}