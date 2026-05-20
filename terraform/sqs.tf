# SQS queue# terraform/sqs.tf
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project_name}-dlq"
  message_retention_seconds = 1209600  # 14 days

  tags = {
    Name    = "${var.project_name}-dlq"
    Project = var.project_name
  }
}

resource "aws_sqs_queue" "processing" {
  name                       = "${var.project_name}-processing"
  visibility_timeout_seconds = 300  

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3 s
  })

  tags = {
    Name    = "${var.project_name}-processing"
    Project = var.project_name
  }
}