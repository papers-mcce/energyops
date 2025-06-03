output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = data.aws_region.current.name
}

output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

# DynamoDB Table Information
output "dynamodb_tables" {
  description = "DynamoDB table names and ARNs"
  value = {
    energy_live_data = {
      name = aws_dynamodb_table.energy_live_data.name
      arn  = aws_dynamodb_table.energy_live_data.arn
    }
    epex_spot_prices = {
      name = aws_dynamodb_table.epex_spot_prices.name
      arn  = aws_dynamodb_table.epex_spot_prices.arn
    }
    sensor_data = {
      name = aws_dynamodb_table.sensor_data.name
      arn  = aws_dynamodb_table.sensor_data.arn
    }
  }
}

# Lambda Function Information
output "lambda_functions" {
  description = "Lambda function names and ARNs"
  value = {
    energylive_collector = {
      name = aws_lambda_function.energylive_collector.function_name
      arn  = aws_lambda_function.energylive_collector.arn
    }
    epex_collector = {
      name = aws_lambda_function.epex_collector.function_name
      arn  = aws_lambda_function.epex_collector.arn
    }
    mqtt_processor = {
      name = aws_lambda_function.mqtt_processor.function_name
      arn  = aws_lambda_function.mqtt_processor.arn
    }
  }
}

# IoT Core Information
output "iot_resources" {
  description = "IoT Core resource information"
  value = {
    thing_name    = aws_iot_thing.netio_device.name
    thing_arn     = aws_iot_thing.netio_device.arn
    certificate_arn = aws_iot_certificate.netio_cert.arn
    certificate_pem = aws_iot_certificate.netio_cert.certificate_pem
    private_key     = aws_iot_certificate.netio_cert.private_key
    public_key      = aws_iot_certificate.netio_cert.public_key
    topic_rule_name = aws_iot_topic_rule.power_data_rule.name
    mqtt_endpoint   = "https://${data.aws_iot_endpoint.mqtt.endpoint_address}"
  }
  sensitive = true
}

# EventBridge Schedule Information
output "eventbridge_schedules" {
  description = "EventBridge schedule information"
  value = {
    energylive_schedule = {
      name       = aws_cloudwatch_event_rule.energylive_schedule.name
      expression = aws_cloudwatch_event_rule.energylive_schedule.schedule_expression
    }
    epex_schedule = {
      name       = aws_cloudwatch_event_rule.epex_schedule.name
      expression = aws_cloudwatch_event_rule.epex_schedule.schedule_expression
    }
  }
}

# IAM Role Information
output "iam_roles" {
  description = "IAM role ARNs"
  value = {
    lambda_execution_role = aws_iam_role.lambda_execution_role.arn
    iot_role             = aws_iam_role.iot_role.arn
    eventbridge_role     = aws_iam_role.eventbridge_role.arn
  }
}

# Data source for IoT endpoint
data "aws_iot_endpoint" "mqtt" {
  endpoint_type = "iot:Data-ATS"
}

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
    
    3. Configure NETIO PowerCable Device:
       - MQTT Endpoint: ${data.aws_iot_endpoint.mqtt.endpoint_address}
       - Topic: ${var.iot_topic_name}
       - Use the certificate and private key from the iot_resources output
    
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
    - IoT certificates are sensitive - store them securely
    - API keys should be managed through AWS Secrets Manager in production
    - Review IAM policies and apply principle of least privilege
    
  EOT
} 