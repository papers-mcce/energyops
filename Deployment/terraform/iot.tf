# IoT Thing for NETIO
resource "aws_iot_thing" "netio_device" {
  name = var.iot_thing_name

  attributes = {
    DeviceType = "NETIO PowerCable"
    Location   = "Server Room"
  }
}

# IoT Thing for NOUS A5T
resource "aws_iot_thing" "nous_a5t_device" {
  name = "${var.project_name}-nous-a5t"

  attributes = {
    DeviceType = "NOUS A5T Power Strip"
    Location   = "Home"
  }
}

# IoT Certificate for NETIO (existing)
resource "aws_iot_certificate" "netio_cert" {
  active = true
}

# IoT Certificate for NOUS A5T (if using certificate auth)
resource "aws_iot_certificate" "nous_cert" {
  active = true
}

# Custom Authorizer for Tasmota (simplified auth)
resource "aws_iot_authorizer" "tasmota_auth" {
  name                    = "TasmotaAuth"
  authorizer_function_arn = aws_lambda_function.tasmota_authorizer.arn
  status                  = "ACTIVE"
  signing_disabled        = true
}

# Lambda function for Tasmota authorization
resource "aws_lambda_function" "tasmota_authorizer" {
  filename         = "tasmota_authorizer.zip"
  function_name    = "${var.project_name}-tasmota-authorizer"
  role            = aws_iam_role.tasmota_authorizer_role.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 30

  # This would need to be created - simplified authorizer
  source_code_hash = data.archive_file.tasmota_authorizer_zip.output_base64sha256
}

# IAM role for Tasmota authorizer
resource "aws_iam_role" "tasmota_authorizer_role" {
  name = "${var.project_name}-tasmota-authorizer-role"

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

# IoT Policy for NETIO (existing)
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

# IoT Policy for Tasmota devices (broader permissions for multiple topics)
resource "aws_iot_policy" "tasmota_policy" {
  name = "${var.project_name}-tasmota-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iot:Connect"
        ]
        Resource = "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:client/tasmota*"
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Publish",
          "iot:Subscribe",
          "iot:Receive"
        ]
        Resource = [
          "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/tele/+/*",
          "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/stat/+/*",
          "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/cmnd/+/*",
          "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topicfilter/tele/+/*",
          "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topicfilter/stat/+/*",
          "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topicfilter/cmnd/+/*"
        ]
      }
    ]
  })
}

# Attach policies to certificates
resource "aws_iot_policy_attachment" "netio_policy_attachment" {
  policy = aws_iot_policy.netio_policy.name
  target = aws_iot_certificate.netio_cert.arn
}

resource "aws_iot_policy_attachment" "tasmota_policy_attachment" {
  policy = aws_iot_policy.tasmota_policy.name
  target = aws_iot_certificate.nous_cert.arn
}

# Attach certificates to things
resource "aws_iot_thing_principal_attachment" "netio_cert_attachment" {
  principal = aws_iot_certificate.netio_cert.arn
  thing     = aws_iot_thing.netio_device.name
}

resource "aws_iot_thing_principal_attachment" "nous_cert_attachment" {
  principal = aws_iot_certificate.nous_cert.arn
  thing     = aws_iot_thing.nous_a5t_device.name
}

# IoT Topic Rule for NETIO power data (existing)
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

# IoT Topic Rule for Tasmota power data
resource "aws_iot_topic_rule" "tasmota_power_data_rule" {
  name        = "${replace(var.project_name, "-", "_")}_tasmota_power_rule"
  description = "Process power consumption data from Tasmota devices"
  enabled     = true
  sql         = "SELECT *, topic() as topic, timestamp() as aws_timestamp FROM 'tele/+/SENSOR'"
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