# =============================================================================
# IAM ROLES AND POLICIES CONFIGURATION
# =============================================================================
# This file defines IAM roles and policies for the Energy Monitoring System
# Follows principle of least privilege for security

# =============================================================================
# LAMBDA EXECUTION ROLE AND POLICIES
# =============================================================================
# IAM role and policies for Lambda functions to access AWS services

# IAM Role for Lambda Functions
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-lambda-execution-role"

  # Trust policy allowing Lambda service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"  # Only Lambda service can assume this role
        }
      }
    ]
  })
}

# Basic Lambda execution policy (CloudWatch Logs access)
# Provides basic permissions for Lambda functions to write logs
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom policy for DynamoDB access
# Allows Lambda functions to read/write data to DynamoDB tables
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "${var.project_name}-lambda-dynamodb-policy"
  description = "Policy for Lambda functions to access DynamoDB tables"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",     # Insert new records
          "dynamodb:GetItem",     # Retrieve single record
          "dynamodb:UpdateItem",  # Update existing record
          "dynamodb:DeleteItem",  # Delete record
          "dynamodb:Query",       # Query with key conditions
          "dynamodb:Scan"         # Scan entire table (use sparingly)
        ]
        Resource = [
          aws_dynamodb_table.energy_live_data.arn,  # EnergyLiveData table
          aws_dynamodb_table.epex_spot_prices.arn,  # EPEXSpotPrices table
          aws_dynamodb_table.sensor_data.arn,       # SensorData table
          "${aws_dynamodb_table.energy_live_data.arn}/index/*"  # All indexes on EnergyLiveData
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
# Allows Lambda functions to publish custom metrics for monitoring
resource "aws_iam_policy" "lambda_cloudwatch_metrics_policy" {
  name        = "${var.project_name}-lambda-cloudwatch-metrics-policy"
  description = "Policy for Lambda functions to publish CloudWatch metrics"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"  # Publish custom metrics
        ]
        Resource = "*"  # CloudWatch metrics don't have specific resource ARNs
      }
    ]
  })
}

# Attach CloudWatch metrics policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_metrics_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_cloudwatch_metrics_policy.arn
}

# =============================================================================
# IOT CORE ROLE AND POLICIES
# =============================================================================
# IAM role and policies for IoT Core to interact with other AWS services

# IAM Role for IoT Core
resource "aws_iam_role" "iot_role" {
  name = "${var.project_name}-iot-role"

  # Trust policy allowing IoT Core service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "iot.amazonaws.com"  # Only IoT Core service can assume this role
        }
      }
    ]
  })
}

# Policy for IoT to invoke Lambda
# Allows IoT Core topic rules to trigger Lambda functions
resource "aws_iam_policy" "iot_lambda_policy" {
  name        = "${var.project_name}-iot-lambda-policy"
  description = "Policy for IoT Core to invoke Lambda functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"  # Permission to invoke Lambda functions
        ]
        Resource = aws_lambda_function.mqtt_processor.arn  # Only the MQTT processor function
      }
    ]
  })
}

# Attach IoT Lambda policy
resource "aws_iam_role_policy_attachment" "iot_lambda_policy_attachment" {
  role       = aws_iam_role.iot_role.name
  policy_arn = aws_iam_policy.iot_lambda_policy.arn
}

# =============================================================================
# EVENTBRIDGE ROLE AND POLICIES
# =============================================================================
# IAM role and policies for EventBridge to invoke Lambda functions on schedule

# IAM Role for EventBridge
resource "aws_iam_role" "eventbridge_role" {
  name = "${var.project_name}-eventbridge-role"

  # Trust policy allowing EventBridge service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"  # Only EventBridge service can assume this role
        }
      }
    ]
  })
}

# Policy for EventBridge to invoke Lambda
# Allows EventBridge rules to trigger Lambda functions on schedule
resource "aws_iam_policy" "eventbridge_lambda_policy" {
  name        = "${var.project_name}-eventbridge-lambda-policy"
  description = "Policy for EventBridge to invoke Lambda functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"  # Permission to invoke Lambda functions
        ]
        Resource = [
          aws_lambda_function.energylive_collector.arn,  # EnergyLIVE collector function
          aws_lambda_function.epex_collector.arn         # EPEX collector function
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

# =============================================================================
# IOT MANAGEMENT POLICY
# =============================================================================
# Policy for managing IoT Core resources during Terraform deployment

# IAM Policy for IoT Core management (needed for Terraform deployment)
resource "aws_iam_policy" "iot_management_policy" {
  name        = "${var.project_name}-iot-management-policy"
  description = "Policy for managing IoT Core resources during deployment"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # IoT Thing management
          "iot:CreateThing",
          "iot:DeleteThing",
          "iot:DescribeThing",
          "iot:UpdateThing",
          "iot:ListThings",
          
          # Certificate management
          "iot:CreateKeysAndCertificate",
          "iot:DeleteCertificate",
          "iot:DescribeCertificate",
          "iot:UpdateCertificate",
          "iot:ListCertificates",
          
          # Policy management
          "iot:CreatePolicy",
          "iot:DeletePolicy",
          "iot:GetPolicy",
          "iot:ListPolicies",
          "iot:AttachPolicy",
          "iot:DetachPolicy",
          
          # Thing-Principal attachment
          "iot:AttachThingPrincipal",
          "iot:DetachThingPrincipal",
          "iot:ListThingPrincipals",
          
          # Topic Rule management
          "iot:CreateTopicRule",
          "iot:DeleteTopicRule",
          "iot:GetTopicRule",
          "iot:ListTopicRules",
          "iot:ReplaceTopicRule",
          
          # Endpoint information
          "iot:DescribeEndpoint"
        ]
        Resource = "*"  # IoT management actions typically require wildcard resource
      }
    ]
  })

  tags = {
    Name        = "IoT Management Policy"
    Description = "Allows management of IoT Core resources for energy monitoring system"
  }
} 