# =============================================================================
# DYNAMODB TABLES CONFIGURATION
# =============================================================================
# This file defines DynamoDB tables for storing energy monitoring data
# Tables are configured with appropriate indexes, TTL, and capacity settings

# =============================================================================
# ENERGYLIVE DATA TABLE
# =============================================================================
# Primary table for storing energy consumption data from smart meters

# DynamoDB table for energyLIVE data
resource "aws_dynamodb_table" "energy_live_data" {
  name           = "EnergyLiveData"
  billing_mode   = "PROVISIONED"  # Use provisioned capacity for predictable costs
  read_capacity  = var.dynamodb_read_capacity * 2  # Higher capacity for main table
  write_capacity = var.dynamodb_write_capacity * 2

  # Primary key structure for efficient querying
  hash_key  = "device_id"   # Partition key: identifies the specific device
  range_key = "timestamp"   # Sort key: allows time-based queries

  # Define attributes used in keys and indexes
  attribute {
    name = "device_id"
    type = "S"  # String type for device identifier
  }

  attribute {
    name = "timestamp"
    type = "N"  # Number type for Unix timestamp
  }

  attribute {
    name = "obis_code"
    type = "S"  # String type for OBIS code
  }

  attribute {
    name = "measurement_name"
    type = "S"  # String type for measurement name
  }

  # Global Secondary Index for querying by OBIS code
  global_secondary_index {
    name            = "ObisCodeIndex"
    hash_key        = "obis_code"  # Query by OBIS code
    range_key       = "timestamp"  # Sort by time
    read_capacity   = var.dynamodb_read_capacity
    write_capacity  = var.dynamodb_write_capacity
    projection_type = "ALL"  # Include all attributes in the index
  }

  # Global Secondary Index for querying by measurement name
  global_secondary_index {
    name            = "MeasurementNameIndex"
    hash_key        = "measurement_name"  # Query by measurement name
    range_key       = "timestamp"         # Sort by time
    read_capacity   = var.dynamodb_read_capacity
    write_capacity  = var.dynamodb_write_capacity
    projection_type = "ALL"  # Include all attributes in the index
  }

  # TTL configuration for automatic data cleanup
  # Prevents unlimited data growth and manages storage costs
  ttl {
    attribute_name = "ttl"     # Attribute containing expiration timestamp
    enabled        = true      # Enable automatic deletion
  }

  tags = {
    Name        = "EnergyLiveData"
    Description = "Stores energy consumption data from smart meters"
  }
}

# =============================================================================
# EPEX SPOT PRICES TABLE
# =============================================================================
# Table for storing electricity market price data

# DynamoDB table for EPEX Spot prices
resource "aws_dynamodb_table" "epex_spot_prices" {
  name           = "EPEXSpotPrices"
  billing_mode   = "PROVISIONED"  # Use provisioned capacity
  read_capacity  = var.dynamodb_read_capacity
  write_capacity = var.dynamodb_write_capacity

  # Primary key for price data
  hash_key  = "tariff"      # Partition key: price tariff type (e.g., EPEXSPOTAT)
  range_key = "timestamp"   # Sort key: time of price data

  # Define key attributes
  attribute {
    name = "tariff"
    type = "S"  # String type for tariff identifier
  }

  attribute {
    name = "timestamp"
    type = "N"  # Number type for Unix timestamp
  }

  # TTL configuration for automatic data cleanup
  # Price data older than retention period will be automatically deleted
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name        = "EPEXSpotPrices"
    Description = "Stores electricity price data from EPEX Spot market"
  }
}

# =============================================================================
# IOT SENSOR DATA TABLE
# =============================================================================
# Table for storing real-time data from IoT devices (NETIO PowerCable, etc.)

# DynamoDB table for IoT sensor data (NETIO PowerCable)
resource "aws_dynamodb_table" "sensor_data" {
  name           = "SensorData"
  billing_mode   = "PROVISIONED"  # Use provisioned capacity
  read_capacity  = var.dynamodb_read_capacity
  write_capacity = var.dynamodb_write_capacity

  # Primary key for sensor data
  hash_key  = "device_id"   # Partition key: identifies the IoT device
  range_key = "timestamp"   # Sort key: time of measurement

  # Define key attributes
  attribute {
    name = "device_id"
    type = "S"  # String type for device identifier
  }

  attribute {
    name = "timestamp"
    type = "S"  # String type for ISO timestamp (different from other tables)
  }

  # TTL configuration for automatic data cleanup
  # Sensor data will be automatically deleted after retention period
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name        = "SensorData"
    Description = "Stores power consumption data from IoT devices"
  }
} 