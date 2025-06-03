# Archive Lambda function code
data "archive_file" "energylive_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../Lambda"
  output_path = "${path.module}/energylive-lambda.zip"
  excludes    = ["test_local.py", "README.md", "*.bash", "*.ps1"]
}

# energyLIVE API Collector Lambda Function
resource "aws_lambda_function" "energylive_collector" {
  filename         = data.archive_file.energylive_lambda_zip.output_path
  function_name    = "${var.project_name}-energylive-collector"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "energylive-api-collector.lambda_handler"
  source_code_hash = data.archive_file.energylive_lambda_zip.output_base64sha256
  runtime         = "python3.9"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  environment {
    variables = {
      API_KEY    = var.energylive_api_key
      DEVICE_UID = var.energylive_device_uid
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_dynamodb_policy_attachment,
    aws_cloudwatch_log_group.energylive_lambda_logs,
  ]

  tags = {
    Name        = "EnergyLIVE API Collector"
    Description = "Collects energy data from energyLIVE API"
  }
}

# EPEX Spot Collector Lambda Function
resource "aws_lambda_function" "epex_collector" {
  filename         = data.archive_file.energylive_lambda_zip.output_path
  function_name    = "${var.project_name}-epex-collector"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "epex-spot-collector.lambda_handler"
  source_code_hash = data.archive_file.energylive_lambda_zip.output_base64sha256
  runtime         = "python3.9"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_dynamodb_policy_attachment,
    aws_cloudwatch_log_group.epex_lambda_logs,
  ]

  tags = {
    Name        = "EPEX Spot Collector"
    Description = "Collects electricity price data from EPEX Spot market"
  }
}

# MQTT Processor Lambda Function
resource "aws_lambda_function" "mqtt_processor" {
  filename         = data.archive_file.energylive_lambda_zip.output_path
  function_name    = "${var.project_name}-mqtt-processor"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "process-mqtt.lambda_handler"
  source_code_hash = data.archive_file.energylive_lambda_zip.output_base64sha256
  runtime         = "python3.9"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_dynamodb_policy_attachment,
    aws_cloudwatch_log_group.mqtt_lambda_logs,
  ]

  tags = {
    Name        = "MQTT Processor"
    Description = "Processes MQTT messages from IoT devices"
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "energylive_lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-energylive-collector"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "epex_lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-epex-collector"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "mqtt_lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-mqtt-processor"
  retention_in_days = 14
}

# Lambda permissions for EventBridge
resource "aws_lambda_permission" "allow_eventbridge_energylive" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.energylive_collector.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.energylive_schedule.arn
}

resource "aws_lambda_permission" "allow_eventbridge_epex" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.epex_collector.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.epex_schedule.arn
}

# Lambda permission for IoT Core
resource "aws_lambda_permission" "allow_iot_core" {
  statement_id  = "AllowExecutionFromIoTCore"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mqtt_processor.function_name
  principal     = "iot.amazonaws.com"
  source_arn    = aws_iot_topic_rule.power_data_rule.arn
} 