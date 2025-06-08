# =============================================================================
# TERRAFORM OUTPUTS CONFIGURATION
# =============================================================================
# This file defines outputs that provide important information after deployment
# Outputs help with configuration, debugging, and integration with other systems

# =============================================================================
# AWS ACCOUNT AND REGION INFORMATION
# =============================================================================
# Basic AWS environment information

# AWS region where resources are deployed
output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = data.aws_region.current.name
}

# AWS account ID for reference and ARN construction
output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

# =============================================================================
# DYNAMODB TABLE INFORMATION
# =============================================================================
# Information about created DynamoDB tables for data storage

# DynamoDB Table Information
output "dynamodb_tables" {
  description = "DynamoDB table names and ARNs"
  value = {
    # EnergyLiveData table for smart meter data
    energy_live_data = {
      name = aws_dynamodb_table.energy_live_data.name
      arn  = aws_dynamodb_table.energy_live_data.arn
    }
    # EPEXSpotPrices table for electricity market prices
    epex_spot_prices = {
      name = aws_dynamodb_table.epex_spot_prices.name
      arn  = aws_dynamodb_table.epex_spot_prices.arn
    }
    # SensorData table for IoT device measurements
    sensor_data = {
      name = aws_dynamodb_table.sensor_data.name
      arn  = aws_dynamodb_table.sensor_data.arn
    }
  }
}

# =============================================================================
# LAMBDA FUNCTION INFORMATION
# =============================================================================
# Information about deployed Lambda functions

# Lambda Function Information
output "lambda_functions" {
  description = "Lambda function names and ARNs"
  value = {
    # EnergyLIVE API data collector
    energylive_collector = {
      name = aws_lambda_function.energylive_collector.function_name
      arn  = aws_lambda_function.energylive_collector.arn
    }
    # EPEX Spot price data collector
    epex_collector = {
      name = aws_lambda_function.epex_collector.function_name
      arn  = aws_lambda_function.epex_collector.arn
    }
    # MQTT message processor for IoT devices
    mqtt_processor = {
      name = aws_lambda_function.mqtt_processor.function_name
      arn  = aws_lambda_function.mqtt_processor.arn
    }
  }
}

# =============================================================================
# IOT CORE INFORMATION
# =============================================================================
# Critical information for configuring IoT devices

# IoT Core Information (Tasmota Device)
output "iot_resources" {
  description = "IoT Core resource information for Tasmota devices"
  value = {
    thing_name    = aws_iot_thing.nous_a5t_device.name           # IoT Thing name (NOUS A5T)
    thing_arn     = aws_iot_thing.nous_a5t_device.arn            # IoT Thing ARN
    telemetry_rule_name = aws_iot_topic_rule.tasmota_telemetry_rule.name  # Telemetry topic rule name
    status_rule_name = aws_iot_topic_rule.tasmota_status_rule.name     # Status topic rule name
    mqtt_endpoint   = data.aws_iot_endpoint.mqtt.endpoint_address  # MQTT endpoint (for BackLog command)
  }
  sensitive = false  # No longer sensitive since no certificates
}

# =============================================================================
# EVENTBRIDGE SCHEDULE INFORMATION
# =============================================================================
# Information about scheduled data collection

# EventBridge Schedule Information
output "eventbridge_schedules" {
  description = "EventBridge schedule information"
  value = {
    # EnergyLIVE data collection schedule
    energylive_schedule = {
      name       = aws_cloudwatch_event_rule.energylive_schedule.name
      expression = aws_cloudwatch_event_rule.energylive_schedule.schedule_expression
    }
    # EPEX Spot price collection schedule
    epex_schedule = {
      name       = aws_cloudwatch_event_rule.epex_schedule.name
      expression = aws_cloudwatch_event_rule.epex_schedule.schedule_expression
    }
  }
}

# =============================================================================
# IAM ROLE INFORMATION
# =============================================================================
# ARNs of created IAM roles for reference

# IAM Role Information
output "iam_roles" {
  description = "IAM role ARNs"
  value = {
    lambda_execution_role = aws_iam_role.lambda_execution_role.arn  # Lambda execution role
    iot_role             = aws_iam_role.iot_role.arn               # IoT Core service role
    eventbridge_role     = aws_iam_role.eventbridge_role.arn       # EventBridge service role
  }
}

# =============================================================================
# DATA SOURCES FOR OUTPUTS
# =============================================================================
# Data sources needed for output values

# Data source for IoT endpoint
data "aws_iot_endpoint" "mqtt" {
  endpoint_type = "iot:Data-ATS"  # Use ATS endpoint for device connections
}

# =============================================================================
# POST-DEPLOYMENT CONFIGURATION INSTRUCTIONS
# =============================================================================
# Comprehensive instructions for configuring the system after deployment

# Configuration Instructions
output "configuration_instructions" {
  description = "Post-deployment configuration instructions"
  value = <<-EOT
    
    🚀 Energy Monitoring System Deployed Successfully!
    
    📋 Next Steps:
    
    1. Update Lambda Environment Variables (if not set during deployment):
       aws lambda update-function-configuration \
         --function-name ${aws_lambda_function.energylive_collector.function_name} \
         --environment Variables='{API_KEY=YOUR_ACTUAL_API_KEY,DEVICE_UID=YOUR_ACTUAL_DEVICE_UID}' \
         --region ${data.aws_region.current.name}
    
    2. Test Lambda Functions:
       aws lambda invoke --function-name ${aws_lambda_function.energylive_collector.function_name} --region ${data.aws_region.current.name} output.json
       aws lambda invoke --function-name ${aws_lambda_function.epex_collector.function_name} --region ${data.aws_region.current.name} output.json
    
    3. Configure Tasmota Device (NOUS A5T):
       - Copy the BackLog command from tasmota_backlog_command output
       - Paste it into the Tasmota web console
       - The device will automatically restart and connect to AWS IoT
       - No certificates needed - uses simplified password authentication
       
       Example BackLog command format:
       BackLog SetOption3 1; SetOption103 1; MqttHost YOUR-ENDPOINT; MqttPort 443; MqttUser tasmota?x-amz-customauthorizer-name=TasmotaAuth; MqttPassword YOUR-PASSWORD
    
    4. Monitor Data Collection:
       - Check CloudWatch Logs for Lambda execution
       - Query DynamoDB tables to verify data storage
       - Monitor EventBridge rules for scheduled execution
    
    📊 DynamoDB Query Examples:
    
    # Query energy data:
    aws dynamodb query --table-name ${aws_dynamodb_table.energy_live_data.name} \
      --key-condition-expression 'device_id = :device_id' \
      --expression-attribute-values '{":device_id":{"S":"YOUR_DEVICE_ID"}}' \
      --region ${data.aws_region.current.name}
    
    # Query EPEX prices:
    aws dynamodb query --table-name ${aws_dynamodb_table.epex_spot_prices.name} \
      --key-condition-expression 'tariff = :tariff' \
      --expression-attribute-values '{":tariff":{"S":"EPEXSPOTAT"}}' \
      --region ${data.aws_region.current.name}
    
    🔐 Security Notes:
    - BackLog command contains sensitive authentication data - handle securely
    - API keys should be managed through AWS Secrets Manager in production
    - Review IAM policies and apply principle of least privilege
    - AWS IoT uses TLS 1.2 for all communications
    - No retained messages are supported in AWS IoT
    
  EOT
} 