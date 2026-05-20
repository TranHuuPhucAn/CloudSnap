# DynamoDB table
resource "aws_dynamodb_table" "jobs" {
  name         = "${var.project_name}-jobs"
  billing_mode = "PAY_PER_REQUEST"  # No capacity planning needed at this scale
  hash_key     = "job_id"

  attribute {
    name = "job_id"
    type = "S"  # String
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true  # Auto-delete old job records
  }

  tags = {
    Name    = "${var.project_name}-jobs"
    Project = var.project_name
  }
}