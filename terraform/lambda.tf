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