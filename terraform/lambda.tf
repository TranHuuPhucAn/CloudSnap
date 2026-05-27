resource "aws_cloudwatch_log_group" "upload_handler" {
  name              = "/aws/lambda/${var.project_name}-upload-handler"
  retention_in_days = 7

  tags = { Project = var.project_name }
}

resource "aws_cloudwatch_log_group" "processor" {
  name              = "/aws/lambda/${var.project_name}-processor"
  retention_in_days = 7

  tags = { Project = var.project_name }
}

resource "aws_lambda_function" "upload_handler" {
  filename         = "../src/upload-handler/upload-handler.zip"
  function_name    = "${var.project_name}-upload-handler"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  source_code_hash = filebase64sha256("../src/upload-handler/upload-handler.zip")

  environment {
    variables = {
      RAW_UPLOADS_BUCKET = aws_s3_bucket.raw_uploads.bucket
      DYNAMODB_TABLE     = aws_dynamodb_table.jobs.name
    }
  }

  depends_on = [aws_cloudwatch_log_group.upload_handler]

  tags = {
    Name    = "${var.project_name}-upload-handler"
    Project = var.project_name
  }
}

resource "aws_lambda_function" "processor" {
  filename         = "../src/processor/processor.zip"
  function_name    = "${var.project_name}-processor"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  timeout          = 300   # 5 minutes — image processing can be slow for large files
  memory_size      = 512   # Pillow needs more memory than the 128MB default

  source_code_hash = filebase64sha256("../src/processor/processor.zip")

  environment {
    variables = {
      PROCESSED_BUCKET = aws_s3_bucket.processed.bucket
      DYNAMODB_TABLE   = aws_dynamodb_table.jobs.name
      SNS_TOPIC_ARN    = aws_sns_topic.notifications.arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.processor]

  tags = {
    Name    = "${var.project_name}-processor"
    Project = var.project_name
  }
}

# Tells Lambda to poll SQS and trigger the processor when messages arrive
resource "aws_lambda_event_source_mapping" "sqs_to_processor" {
  event_source_arn = aws_sqs_queue.processing.arn
  function_name    = aws_lambda_function.processor.arn
  batch_size       = 1  # Process one image at a time — safe for error isolation
}