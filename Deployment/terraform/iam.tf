# IAM Role for Lambda Functions
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-lambda-execution-role"

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

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom policy for DynamoDB access
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "${var.project_name}-lambda-dynamodb-policy"
  description = "Policy for Lambda functions to access DynamoDB tables"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.energy_live_data.arn,
          aws_dynamodb_table.epex_spot_prices.arn,
          aws_dynamodb_table.sensor_data.arn,
          "${aws_dynamodb_table.energy_live_data.arn}/index/*"
        ]
      }
    ]
  })
}

# Attach DynamoDB policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

# Custom policy for CloudWatch metrics
resource "aws_iam_policy" "lambda_cloudwatch_metrics_policy" {
  name        = "${var.project_name}-lambda-cloudwatch-metrics-policy"
  description = "Policy for Lambda functions to publish CloudWatch metrics"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach CloudWatch metrics policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_metrics_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_cloudwatch_metrics_policy.arn
}

# IAM Role for IoT Core
resource "aws_iam_role" "iot_role" {
  name = "${var.project_name}-iot-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "iot.amazonaws.com"
        }
      }
    ]
  })
}

# Policy for IoT to invoke Lambda
resource "aws_iam_policy" "iot_lambda_policy" {
  name        = "${var.project_name}-iot-lambda-policy"
  description = "Policy for IoT Core to invoke Lambda functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.mqtt_processor.arn
      }
    ]
  })
}

# Attach IoT Lambda policy
resource "aws_iam_role_policy_attachment" "iot_lambda_policy_attachment" {
  role       = aws_iam_role.iot_role.name
  policy_arn = aws_iam_policy.iot_lambda_policy.arn
}

# IAM Role for EventBridge
resource "aws_iam_role" "eventbridge_role" {
  name = "${var.project_name}-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })
}

# Policy for EventBridge to invoke Lambda
resource "aws_iam_policy" "eventbridge_lambda_policy" {
  name        = "${var.project_name}-eventbridge-lambda-policy"
  description = "Policy for EventBridge to invoke Lambda functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.energylive_collector.arn,
          aws_lambda_function.epex_collector.arn
        ]
      }
    ]
  })
}

# Attach EventBridge Lambda policy
resource "aws_iam_role_policy_attachment" "eventbridge_lambda_policy_attachment" {
  role       = aws_iam_role.eventbridge_role.name
  policy_arn = aws_iam_policy.eventbridge_lambda_policy.arn
} 