# =============================================================================
# LAMBDA FUNCTIONS CONFIGURATION
# =============================================================================
# This file defines AWS Lambda functions for the Energy Monitoring System
# Functions handle data collection, processing, and storage operations

# =============================================================================
# LAMBDA DEPLOYMENT PACKAGE WITH DEPENDENCIES
# =============================================================================
# Create ZIP archive of Lambda function code with dependencies for deployment

# Archive source code for change detection
data "archive_file" "lambda_source_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../Lambda"
  output_path = "${path.module}/lambda-source.zip"
  excludes    = ["test_local.py", "README.md", "*.bash", "*.ps1", "package/", "lambda-deployment.zip"]
}

# Install dependencies and create deployment package
resource "null_resource" "lambda_dependencies" {
  triggers = {
    requirements = filemd5("${path.module}/../Lambda/requirements.txt")
    source_code  = data.archive_file.lambda_source_zip.output_base64sha256
    script       = filemd5("${path.module}/create_lambda_package.sh")
  }

  provisioner "local-exec" {
    command = "chmod +x ${path.module}/create_lambda_package.sh && ${path.module}/create_lambda_package.sh '${path.module}/../Lambda'"
    interpreter = ["/bin/bash", "-c"]
  }
}

# Get the hash of the deployment package
data "archive_file" "lambda_deployment_zip" {
  type        = "zip"
  source_file = "${path.module}/../Lambda/lambda-deployment.zip"
  output_path = "${path.module}/lambda-deployment.zip"
  depends_on  = [null_resource.lambda_dependencies]
}

# =============================================================================
# ENERGYLIVE API COLLECTOR LAMBDA
# =============================================================================
# Lambda function that collects energy data from energyLIVE smart meter API

# energyLIVE API Collector Lambda Function
resource "aws_lambda_function" "energylive_collector" {
  filename         = "${path.module}/../Lambda/lambda-deployment.zip"
  function_name    = "${var.project_name}-energylive-collector"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "energylive-api-collector.lambda_handler"  # Python function entry point
  source_code_hash = data.archive_file.lambda_deployment_zip.output_base64sha256
  runtime         = "python3.9"  # Python runtime version
  timeout         = var.lambda_timeout      # Maximum execution time
  memory_size     = var.lambda_memory_size  # Memory allocation

  # Environment variables for the Lambda function
  # These provide configuration without hardcoding values in the code
  environment {
    variables = {
      API_KEY    = var.energylive_api_key    # energyLIVE API authentication key
      DEVICE_UID = var.energylive_device_uid # Smart meter device identifier
    }
  }

  # Ensure dependencies are created before this function
  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_dynamodb_policy_attachment,
    aws_cloudwatch_log_group.energylive_lambda_logs,
    null_resource.lambda_dependencies,
    data.archive_file.lambda_deployment_zip,
  ]

  tags = {
    Name        = "EnergyLIVE API Collector"
    Description = "Collects energy data from energyLIVE API"
  }
}

# =============================================================================
# EPEX SPOT COLLECTOR LAMBDA
# =============================================================================
# Lambda function that collects electricity price data from EPEX Spot market

# EPEX Spot Collector Lambda Function
resource "aws_lambda_function" "epex_collector" {
  filename         = "${path.module}/../Lambda/lambda-deployment.zip"
  function_name    = "${var.project_name}-epex-collector"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "epex-spot-collector.lambda_handler"  # Python function entry point
  source_code_hash = data.archive_file.lambda_deployment_zip.output_base64sha256
  runtime         = "python3.9"  # Python runtime version
  timeout         = var.lambda_timeout      # Maximum execution time
  memory_size     = var.lambda_memory_size  # Memory allocation

  # This function doesn't need environment variables as it uses public APIs
  # EPEX Spot data is publicly available without authentication

  # Ensure dependencies are created before this function
  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_dynamodb_policy_attachment,
    aws_cloudwatch_log_group.epex_lambda_logs,
    null_resource.lambda_dependencies,
    data.archive_file.lambda_deployment_zip,
  ]

  tags = {
    Name        = "EPEX Spot Collector"
    Description = "Collects electricity price data from EPEX Spot market"
  }
}

# =============================================================================
# MQTT PROCESSOR LAMBDA
# =============================================================================
# Lambda function that processes MQTT messages from IoT devices

# MQTT Processor Lambda Function
resource "aws_lambda_function" "mqtt_processor" {
  filename         = "${path.module}/../Lambda/lambda-deployment.zip"
  function_name    = "${var.project_name}-mqtt-processor"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "process-mqtt.lambda_handler"  # Python function entry point
  source_code_hash = data.archive_file.lambda_deployment_zip.output_base64sha256
  runtime         = "python3.9"  # Python runtime version
  timeout         = var.lambda_timeout      # Maximum execution time
  memory_size     = var.lambda_memory_size  # Memory allocation

  # Environment variables for MQTT processing
  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.sensor_data.name  # DynamoDB table for storing IoT sensor data
    }
  }

  # Ensure dependencies are created before this function
  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_dynamodb_policy_attachment,
    aws_cloudwatch_log_group.mqtt_lambda_logs,
    null_resource.lambda_dependencies,
    data.archive_file.lambda_deployment_zip,
  ]

  tags = {
    Name        = "MQTT Processor"
    Description = "Processes MQTT messages from IoT devices"
  }
}

# =============================================================================
# CLOUDWATCH LOG GROUPS
# =============================================================================
# Log groups for Lambda function execution logs with retention policies

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "energylive_lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-energylive-collector"
  retention_in_days = 14  # Keep logs for 2 weeks to manage costs
}

resource "aws_cloudwatch_log_group" "epex_lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-epex-collector"
  retention_in_days = 14  # Keep logs for 2 weeks to manage costs
}

resource "aws_cloudwatch_log_group" "mqtt_lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-mqtt-processor"
  retention_in_days = 14  # Keep logs for 2 weeks to manage costs
}

# =============================================================================
# LAMBDA PERMISSIONS
# =============================================================================
# Permissions allowing other AWS services to invoke Lambda functions

# Lambda permissions for EventBridge (scheduled execution)
resource "aws_lambda_permission" "allow_eventbridge_energylive" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.energylive_collector.function_name
  principal     = "events.amazonaws.com"  # EventBridge service
  source_arn    = aws_cloudwatch_event_rule.energylive_schedule.arn
}

resource "aws_lambda_permission" "allow_eventbridge_epex" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.epex_collector.function_name
  principal     = "events.amazonaws.com"  # EventBridge service
  source_arn    = aws_cloudwatch_event_rule.epex_schedule.arn
}

# Lambda permission for IoT Core (MQTT message processing)
resource "aws_lambda_permission" "allow_iot_core" {
  statement_id  = "AllowExecutionFromIoTCore"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mqtt_processor.function_name
  principal     = "iot.amazonaws.com"  # IoT Core service
} 