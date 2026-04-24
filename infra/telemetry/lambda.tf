# Lambda function — receives OTLP traces, stores in S3, forwards to Grafana Cloud

data "archive_file" "collector" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.build/collector.zip"
}

resource "aws_lambda_function" "collector" {
  function_name    = "${var.project_name}-collector"
  description      = "Receives OTLP traces, compresses to S3, forwards to Grafana Cloud"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  architectures    = ["arm64"]
  memory_size      = 128
  timeout          = 10
  filename         = data.archive_file.collector.output_path
  source_code_hash = data.archive_file.collector.output_base64sha256

  environment {
    variables = {
      S3_BUCKET              = aws_s3_bucket.telemetry.id
      GRAFANA_OTLP_ENDPOINT  = var.grafana_otlp_endpoint
      GRAFANA_INSTANCE_ID    = var.grafana_instance_id
      GRAFANA_API_KEY        = var.grafana_api_key
    }
  }
}

# IAM role and policies

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "s3_write" {
  name = "${var.project_name}-s3-write"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.telemetry.arn}/traces/*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-collector"
  retention_in_days = 7
}
