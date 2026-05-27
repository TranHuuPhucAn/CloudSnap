# S3 buckets
resource "aws_s3_bucket" "raw_uploads" {
  bucket = "${var.project_name}-raw-uploads-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name    = "${var.project_name}-raw-uploads"
    Project = var.project_name
  }
}

resource "aws_s3_bucket" "processed" {
  bucket = "${var.project_name}-processed-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name    = "${var.project_name}-processed"
    Project = var.project_name
  }
}

# Block all public access — buckets should never be accidentally public
resource "aws_s3_bucket_public_access_block" "raw_uploads" {
  bucket                  = aws_s3_bucket.raw_uploads.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "processed" {
  bucket                  = aws_s3_bucket.processed.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Auto-delete raw uploads after 7 days to control storage costs
resource "aws_s3_bucket_lifecycle_configuration" "raw_uploads" {
  bucket = aws_s3_bucket.raw_uploads.id

  rule {
    id     = "expire-raw-uploads"
    status = "Enabled"

    filter {}

    expiration {
      days = 7
    }
  }
}

resource "aws_s3_bucket_notification" "raw_uploads" {
  bucket = aws_s3_bucket.raw_uploads.id

  queue {
    queue_arn = aws_sqs_queue.processing.arn
    events    = ["s3:ObjectCreated:*"]
  }

  # S3 policy must exist before the notification can be attached
  depends_on = [aws_sqs_queue_policy.s3_to_sqs]
}

# Fetch current account ID (used in bucket naming above)
data "aws_caller_identity" "current" {}