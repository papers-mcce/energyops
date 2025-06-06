# CloudFormation stack for Tasmota authentication
resource "aws_cloudformation_stack" "tasmota_auth" {
  name = "${var.project_name}-tasmota-auth"

  template_url = "https://s3.amazonaws.com/tasmota-aws-iot/TasmotaAuth.yaml"
  
  parameters = {
    RetentionPolicy = "Retain"
  }

  capabilities = ["CAPABILITY_IAM"]

  tags = {
    Name        = "Tasmota Authentication"
    Project     = var.project_name
    Description = "Simplified authentication for Tasmota devices"
  }
}

# IoT Thing for NOUS A5T
resource "aws_iot_thing" "nous_a5t_device" {
  name = "${var.project_name}-nous-a5t"

  attributes = {
    DeviceType = "NOUS A5T Power Strip"
    Location   = "Home"
    Firmware   = "Tasmota"
  }
}

# IoT Topic Rule for Tasmota telemetry data
resource "aws_iot_topic_rule" "tasmota_telemetry_rule" {
  name        = "${replace(var.project_name, "-", "_")}_tasmota_telemetry"
  description = "Process telemetry data from Tasmota devices"
  enabled     = true
  sql         = "SELECT *, topic() as topic, timestamp() as aws_timestamp FROM 'tele/+/SENSOR' WHERE ENERGY IS NOT NULL"
  sql_version = "2016-03-23"

  lambda {
    function_arn = aws_lambda_function.mqtt_processor.arn
  }

  tags = {
    Name    = "Tasmota Telemetry Rule"
    Project = var.project_name
  }
}

# IoT Topic Rule for Tasmota status updates
resource "aws_iot_topic_rule" "tasmota_status_rule" {
  name        = "${replace(var.project_name, "-", "_")}_tasmota_status"
  description = "Process status updates from Tasmota devices"
  enabled     = true
  sql         = "SELECT *, topic() as topic, timestamp() as aws_timestamp FROM 'stat/+/+'"
  sql_version = "2016-03-23"

  lambda {
    function_arn = aws_lambda_function.mqtt_processor.arn
  }

  tags = {
    Name    = "Tasmota Status Rule"
    Project = var.project_name
  }
}

# Output the BackLog command for device configuration
output "tasmota_backlog_command" {
  description = "BackLog command to configure Tasmota device"
  value       = aws_cloudformation_stack.tasmota_auth.outputs["BackLogCommand"]
  sensitive   = true
}

# Output the MQTT endpoint
output "aws_iot_endpoint" {
  description = "AWS IoT MQTT endpoint"
  value       = data.aws_iot_endpoint.current.endpoint_address
}

# Data source for IoT endpoint
data "aws_iot_endpoint" "current" {
  endpoint_type = "iot:Data-ATS"
} 