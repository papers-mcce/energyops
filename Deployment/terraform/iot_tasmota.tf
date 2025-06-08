# =============================================================================
# TASMOTA-SPECIFIC IOT CONFIGURATION
# =============================================================================
# This file defines IoT Core resources specifically for Tasmota firmware devices
# Includes simplified authentication and topic rules for Tasmota MQTT patterns

# =============================================================================
# TASMOTA AUTHENTICATION STACK
# =============================================================================
# CloudFormation stack providing simplified authentication for Tasmota devices

# CloudFormation stack for Tasmota authentication
resource "aws_cloudformation_stack" "tasmota_auth" {
  name = "${var.project_name}-tasmota-auth"

  # Local CloudFormation template for Tasmota authentication
  # This template creates a custom authorizer that simplifies device onboarding
  # Using local template file from GitHub repo
  template_body = file("${path.module}/TasmotaAuth.yaml")
  
  parameters = {
    RetentionPolicy = "Retain"  # Keep resources when stack is deleted
    MQTTAuthorizerName = "TasmotaAuth"  # Name of the custom authorizer
  }

  capabilities = ["CAPABILITY_IAM"]  # Allow creation of IAM resources

  tags = {
    Name        = "Tasmota Authentication"
    Project     = var.project_name
    Description = "Simplified authentication for Tasmota devices"
  }
}

# =============================================================================
# TASMOTA IOT RESOURCES
# =============================================================================
# IoT resources specifically for Tasmota devices

# IoT Thing for NOUS A5T
resource "aws_iot_thing" "nous_a5t_device" {
  name = "${var.project_name}-nous-a5t"

  # Device attributes specific to Tasmota firmware
  # Note: Attribute values cannot contain spaces
  attributes = {
    DeviceType = "NOUS-A5T-PowerStrip"  # Hardware model (no spaces)
    Location   = "Home"                 # Physical location
    Firmware   = "Tasmota"             # Firmware type
  }
}

# Note: Certificate-based authentication is no longer needed with the new simplified method
# The CloudFormation stack handles all authentication via password-based method

# =============================================================================
# TASMOTA TOPIC RULES
# =============================================================================
# IoT Topic Rules that handle Tasmota's specific MQTT topic patterns

# IoT Topic Rule for Tasmota telemetry data
resource "aws_iot_topic_rule" "tasmota_telemetry_rule" {
  name        = "${replace(var.project_name, "-", "_")}_tasmota_telemetry"
  description = "Process telemetry data from Tasmota devices"
  enabled     = true
  # SQL query to select all SENSOR messages from Tasmota devices
  # Lambda function will filter for energy data to avoid complex SQL WHERE clauses
  sql         = "SELECT *, topic() as topic, timestamp() as aws_timestamp FROM 'tele/+/SENSOR'"
  sql_version = "2016-03-23"

  # Action: Forward filtered messages to Lambda for processing
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
  # SQL query to capture all status messages from Tasmota devices
  # stat/+/+ pattern captures: stat/device_name/RESULT, stat/device_name/POWER, etc.
  sql         = "SELECT *, topic() as topic, timestamp() as aws_timestamp FROM 'stat/+/+'"
  sql_version = "2016-03-23"

  # Action: Forward status messages to Lambda for processing
  lambda {
    function_arn = aws_lambda_function.mqtt_processor.arn
  }

  tags = {
    Name    = "Tasmota Status Rule"
    Project = var.project_name
  }
}

# =============================================================================
# TASMOTA CONFIGURATION OUTPUTS
# =============================================================================
# Outputs providing configuration information for Tasmota devices

# Output the BackLog command for device configuration
# This command can be used to configure Tasmota devices for AWS IoT connectivity
output "tasmota_backlog_command" {
  description = "BackLog command to configure Tasmota device"
  value       = aws_cloudformation_stack.tasmota_auth.outputs["BackLogCommand"]
  sensitive   = true  # Mark as sensitive since it may contain authentication details
}

# Output the MQTT endpoint
# Tasmota devices need this endpoint to connect to AWS IoT Core
output "aws_iot_endpoint" {
  description = "AWS IoT MQTT endpoint"
  value       = data.aws_iot_endpoint.current.endpoint_address
}

# =============================================================================
# DATA SOURCES
# =============================================================================
# Data sources for retrieving AWS IoT Core and account information

# Data source for IoT endpoint
# Retrieves the AWS IoT Core MQTT endpoint for this region
data "aws_iot_endpoint" "current" {
  endpoint_type = "iot:Data-ATS"  # Use the ATS (Amazon Trust Services) endpoint
}