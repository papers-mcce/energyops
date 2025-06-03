# IoT Thing
resource "aws_iot_thing" "netio_device" {
  name = var.iot_thing_name

  attributes = {
    DeviceType = "NETIO PowerCable"
    Location   = "Server Room"
  }
}

# IoT Certificate
resource "aws_iot_certificate" "netio_cert" {
  active = true
}

# IoT Policy
resource "aws_iot_policy" "netio_policy" {
  name = "${var.project_name}-netio-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iot:Connect"
        ]
        Resource = "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:client/${var.iot_thing_name}"
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Publish"
        ]
        Resource = "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/${var.iot_topic_name}"
      }
    ]
  })
}

# Attach policy to certificate
resource "aws_iot_policy_attachment" "netio_policy_attachment" {
  policy = aws_iot_policy.netio_policy.name
  target = aws_iot_certificate.netio_cert.arn
}

# Attach certificate to thing
resource "aws_iot_thing_principal_attachment" "netio_cert_attachment" {
  principal = aws_iot_certificate.netio_cert.arn
  thing     = aws_iot_thing.netio_device.name
}

# IoT Topic Rule to process incoming messages
resource "aws_iot_topic_rule" "power_data_rule" {
  name        = "${replace(var.project_name, "-", "_")}_power_data_rule"
  description = "Process power consumption data from NETIO devices"
  enabled     = true
  sql         = "SELECT *, topic() as topic, timestamp() as aws_timestamp FROM 'topic/${var.iot_topic_name}'"
  sql_version = "2016-03-23"

  lambda {
    function_arn = aws_lambda_function.mqtt_processor.arn
  }
}

# CloudWatch Log Group for IoT Core
resource "aws_cloudwatch_log_group" "iot_logs" {
  name              = "/aws/iot/${var.project_name}"
  retention_in_days = 14
} 