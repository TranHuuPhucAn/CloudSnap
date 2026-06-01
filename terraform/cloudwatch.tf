locals {
  region       = var.aws_region
  upload_fn    = aws_lambda_function.upload_handler.function_name
  processor_fn = aws_lambda_function.processor.function_name
  status_fn    = aws_lambda_function.status_handler.function_name
  api_id       = aws_apigatewayv2_api.main.id
  queue_name   = aws_sqs_queue.processing.name
  dlq_name     = aws_sqs_queue.dlq.name
  table_name   = aws_dynamodb_table.jobs.name
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0; y = 0; width = 8; height = 6
        properties = {
          title  = "API Gateway — Request Count"
          region = local.region
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiId", local.api_id]
          ]
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 8; y = 0; width = 8; height = 6
        properties = {
          title  = "API Gateway — Latency (ms)"
          region = local.region
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiId", local.api_id, { stat = "p50", label = "p50" }],
            ["AWS/ApiGateway", "Latency", "ApiId", local.api_id, { stat = "p99", label = "p99" }]
          ]
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 16; y = 0; width = 8; height = 6
        properties = {
          title  = "API Gateway — Error Rates"
          region = local.region
          metrics = [
            ["AWS/ApiGateway", "4XXError", "ApiId", local.api_id, { label = "4XX Client Errors" }],
            ["AWS/ApiGateway", "5XXError", "ApiId", local.api_id, { label = "5XX Server Errors" }]
          ]
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
        }
      },

      {
        type   = "metric"
        x      = 0; y = 6; width = 12; height = 6
        properties = {
          title  = "Lambda — Invocations"
          region = local.region
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", local.upload_fn, { label = "Upload Handler" }],
            ["AWS/Lambda", "Invocations", "FunctionName", local.processor_fn, { label = "Processor" }],
            ["AWS/Lambda", "Invocations", "FunctionName", local.status_fn, { label = "Status Handler" }]
          ]
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12; y = 6; width = 12; height = 6
        properties = {
          title  = "Lambda — Errors"
          region = local.region
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", local.upload_fn, { label = "Upload Handler" }],
            ["AWS/Lambda", "Errors", "FunctionName", local.processor_fn, { label = "Processor" }],
            ["AWS/Lambda", "Errors", "FunctionName", local.status_fn, { label = "Status Handler" }]
          ]
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0; y = 12; width = 12; height = 6
        properties = {
          title  = "Lambda — Duration (ms)"
          region = local.region
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", local.upload_fn, { stat = "p99", label = "Upload p99" }],
            ["AWS/Lambda", "Duration", "FunctionName", local.processor_fn, { stat = "p99", label = "Processor p99" }],
            ["AWS/Lambda", "Duration", "FunctionName", local.status_fn, { stat = "p99", label = "Status p99" }]
          ]
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12; y = 12; width = 12; height = 6
        properties = {
          title  = "Lambda — Throttles"
          region = local.region
          metrics = [
            ["AWS/Lambda", "Throttles", "FunctionName", local.upload_fn, { label = "Upload Handler" }],
            ["AWS/Lambda", "Throttles", "FunctionName", local.processor_fn, { label = "Processor" }],
            ["AWS/Lambda", "Throttles", "FunctionName", local.status_fn, { label = "Status Handler" }]
          ]
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
        }
      },

      {
        type   = "metric"
        x      = 0; y = 18; width = 12; height = 6
        properties = {
          title  = "SQS — Messages in Queue"
          region = local.region
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", local.queue_name, { label = "Processing Queue" }],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", local.dlq_name, { label = "Dead Letter Queue" }]
          ]
          period = 60
          stat   = "Maximum"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12; y = 18; width = 12; height = 6
        properties = {
          title  = "DynamoDB — Request Latency (ms)"
          region = local.region
          metrics = [
            ["AWS/DynamoDB", "SuccessfulRequestLatency", "TableName", local.table_name, "Operation", "PutItem", { label = "PutItem" }],
            ["AWS/DynamoDB", "SuccessfulRequestLatency", "TableName", local.table_name, "Operation", "GetItem", { label = "GetItem" }],
            ["AWS/DynamoDB", "SuccessfulRequestLatency", "TableName", local.table_name, "Operation", "UpdateItem", { label = "UpdateItem" }]
          ]
          period = 60
          stat   = "p99"
          view   = "timeSeries"
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "upload_handler_errors" {
  alarm_name          = "${var.project_name}-upload-handler-errors"
  alarm_description   = "Upload handler Lambda error rate is too high"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = aws_lambda_function.upload_handler.function_name }
  statistic           = "Sum"
  period              = 60       
  evaluation_periods  = 2        
  threshold           = 3        
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"  
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]  

  tags = { Project = var.project_name }
}

resource "aws_cloudwatch_metric_alarm" "processor_errors" {
  alarm_name          = "${var.project_name}-processor-errors"
  alarm_description   = "Processor Lambda error rate is too high"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = aws_lambda_function.processor.function_name }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 3
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  tags = { Project = var.project_name }
}

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${var.project_name}-dlq-messages"
  alarm_description   = "Messages are arriving in the Dead Letter Queue — jobs are failing after 3 retries"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.dlq.name }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1        
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  tags = { Project = var.project_name }
}

resource "aws_cloudwatch_metric_alarm" "api_5xx_errors" {
  alarm_name          = "${var.project_name}-api-5xx-errors"
  alarm_description   = "API Gateway 5XX error rate is elevated"
  namespace           = "AWS/ApiGateway"
  metric_name         = "5XXError"
  dimensions          = { ApiId = aws_apigatewayv2_api.main.id }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  tags = { Project = var.project_name }
}

resource "aws_cloudwatch_metric_alarm" "processor_duration" {
  alarm_name          = "${var.project_name}-processor-duration"
  alarm_description   = "Processor Lambda p99 duration is approaching the 5 minute timeout"
  namespace           = "AWS/Lambda"
  metric_name         = "Duration"
  dimensions          = { FunctionName = aws_lambda_function.processor.function_name }
  extended_statistic  = "p99"
  period              = 300
  evaluation_periods  = 1
  threshold           = 240000   # Alert at 4 minutes (80% of the 5 min timeout)
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  tags = { Project = var.project_name }
}