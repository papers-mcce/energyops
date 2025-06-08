# =============================================================================
# IOT CORE GENERAL CONFIGURATION
# =============================================================================
# This file defines general AWS IoT Core resources for the Energy Monitoring System
# Device-specific configurations are in separate files (e.g., iot_tasmota.tf)

# =============================================================================
# CLOUDWATCH LOGGING
# =============================================================================
# CloudWatch log group for IoT Core logging and debugging

# CloudWatch Log Group for IoT Core
resource "aws_cloudwatch_log_group" "iot_logs" {
  name              = "/aws/iot/${var.project_name}"
  retention_in_days = 14  # Keep IoT logs for 2 weeks
} 