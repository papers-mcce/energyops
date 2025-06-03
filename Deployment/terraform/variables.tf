variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "energy-monitoring"
}

# energyLIVE API Configuration
variable "energylive_api_key" {
  description = "API key for energyLIVE API"
  type        = string
  sensitive   = true
  default     = ""
}

variable "energylive_device_uid" {
  description = "Device UID for energyLIVE API (e.g., I-10082023-01658401)"
  type        = string
  default     = ""
}

# Lambda Configuration
variable "lambda_timeout" {
  description = "Timeout for Lambda functions in seconds"
  type        = number
  default     = 60
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda functions in MB"
  type        = number
  default     = 256
}

# DynamoDB Configuration
variable "dynamodb_read_capacity" {
  description = "Read capacity units for DynamoDB tables"
  type        = number
  default     = 5
}

variable "dynamodb_write_capacity" {
  description = "Write capacity units for DynamoDB tables"
  type        = number
  default     = 5
}

# EventBridge Schedule Configuration
variable "energylive_schedule_expression" {
  description = "Schedule expression for energyLIVE data collection"
  type        = string
  default     = "rate(5 minutes)"
}

variable "epex_schedule_expression" {
  description = "Schedule expression for EPEX price data collection"
  type        = string
  default     = "rate(15 minutes)"
}

# IoT Configuration
variable "iot_thing_name" {
  description = "Name for the IoT Thing"
  type        = string
  default     = "netio-powercable-1"
}

variable "iot_topic_name" {
  description = "MQTT topic name for IoT messages"
  type        = string
  default     = "sensors/power/data"
} 