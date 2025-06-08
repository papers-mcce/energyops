# =============================================================================
# TERRAFORM VARIABLES CONFIGURATION
# =============================================================================
# This file defines all input variables for the Energy Monitoring System
# Variables allow customization of the deployment without modifying the code

# =============================================================================
# CORE AWS CONFIGURATION
# =============================================================================

# AWS region where all resources will be deployed
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-central-1"  # Frankfurt region - good for European deployments
}

# Environment identifier (dev, staging, prod)
# Used for resource naming and tagging to separate environments
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Project name used as prefix for resource naming
# Helps identify resources belonging to this project
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "energy-monitoring"
}

# =============================================================================
# ENERGYLIVE API CONFIGURATION
# =============================================================================
# Configuration for the energyLIVE smart meter API integration

# API key for accessing energyLIVE API
# This should be set via terraform.tfvars or environment variables
variable "energylive_api_key" {
  description = "API key for energyLIVE API"
  type        = string
  sensitive   = true  # Marks this as sensitive to prevent logging
  default     = ""
}

# Unique device identifier for the energyLIVE smart meter
# Format: I-DDMMYYYY-XXXXXXXX (e.g., I-10082023-01658401)
variable "energylive_device_uid" {
  description = "Device UID for energyLIVE API (e.g., I-10082023-01658401)"
  type        = string
  default     = ""
}

# =============================================================================
# LAMBDA FUNCTION CONFIGURATION
# =============================================================================
# Settings for AWS Lambda functions that process data

# Maximum execution time for Lambda functions in seconds
# Increase if functions need more time to process data
variable "lambda_timeout" {
  description = "Timeout for Lambda functions in seconds"
  type        = number
  default     = 60  # 1 minute should be sufficient for most operations
}

# Memory allocation for Lambda functions in MB
# More memory = faster execution but higher cost
variable "lambda_memory_size" {
  description = "Memory size for Lambda functions in MB"
  type        = number
  default     = 256  # 256MB is usually sufficient for data processing
}

# =============================================================================
# DYNAMODB CONFIGURATION
# =============================================================================
# Settings for DynamoDB tables that store energy and price data

# Read capacity units for DynamoDB tables
# Higher values = better read performance but higher cost
variable "dynamodb_read_capacity" {
  description = "Read capacity units for DynamoDB tables"
  type        = number
  default     = 5  # 5 RCU should handle moderate read loads
}

# Write capacity units for DynamoDB tables
# Higher values = better write performance but higher cost
variable "dynamodb_write_capacity" {
  description = "Write capacity units for DynamoDB tables"
  type        = number
  default     = 5  # 5 WCU should handle regular data ingestion
}

# =============================================================================
# EVENTBRIDGE SCHEDULE CONFIGURATION
# =============================================================================
# Cron-like expressions for automated data collection

# How often to collect data from energyLIVE API
# energyLIVE updates every 5 minutes, so this frequency is optimal
variable "energylive_schedule_expression" {
  description = "Schedule expression for energyLIVE data collection"
  type        = string
  default     = "rate(5 minutes)"  # Collect every 5 minutes (matches API update frequency)
}

# How often to collect electricity price data from EPEX Spot
# EPEX publishes day-ahead prices once daily at 17:00 CET
# Check twice daily: once after 17:00 for next day, once in morning for current day
variable "epex_schedule_expression" {
  description = "Schedule expression for EPEX price data collection"
  type        = string
  default     = "cron(0 6,18 * * ? *)"  # Daily at 06:00 and 18:00 CET
}

# =============================================================================
# IOT CORE CONFIGURATION
# =============================================================================
# Settings for AWS IoT Core integration with smart devices
# Note: Device-specific configurations are now in iot_tasmota.tf

# =============================================================================
# TASMOTA DEVICE CONFIGURATION
# =============================================================================
# Settings specific to Tasmota firmware-based devices

# Prefix used for naming Tasmota devices in IoT Core
variable "tasmota_device_prefix" {
  description = "Prefix for Tasmota device names"
  type        = string
  default     = "tasmota"
}

# Specific name for the NOUS A5T power strip device
# NOUS A5T is a smart power strip with individual outlet control
variable "nous_a5t_device_name" {
  description = "Name for the NOUS A5T device"
  type        = string
  default     = "nous-a5t-powerstrip"
} 