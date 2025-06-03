# DynamoDB table for energyLIVE data
resource "aws_dynamodb_table" "energy_live_data" {
  name           = "EnergyLiveData"
  billing_mode   = "PROVISIONED"
  read_capacity  = var.dynamodb_read_capacity * 2  # Higher capacity for main table
  write_capacity = var.dynamodb_write_capacity * 2

  hash_key  = "device_id"
  range_key = "timestamp"

  attribute {
    name = "device_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "measurement_type"
    type = "S"
  }

  # Global Secondary Index for querying by measurement type
  global_secondary_index {
    name            = "MeasurementTypeIndex"
    hash_key        = "measurement_type"
    range_key       = "timestamp"
    read_capacity   = var.dynamodb_read_capacity
    write_capacity  = var.dynamodb_write_capacity
    projection_type = "ALL"
  }

  # TTL configuration for automatic data cleanup
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name        = "EnergyLiveData"
    Description = "Stores energy consumption data from smart meters"
  }
}

# DynamoDB table for EPEX Spot prices
resource "aws_dynamodb_table" "epex_spot_prices" {
  name           = "EPEXSpotPrices"
  billing_mode   = "PROVISIONED"
  read_capacity  = var.dynamodb_read_capacity
  write_capacity = var.dynamodb_write_capacity

  hash_key  = "tariff"
  range_key = "timestamp"

  attribute {
    name = "tariff"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  # TTL configuration for automatic data cleanup
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name        = "EPEXSpotPrices"
    Description = "Stores electricity price data from EPEX Spot market"
  }
}

# DynamoDB table for IoT sensor data (NETIO PowerCable)
resource "aws_dynamodb_table" "sensor_data" {
  name           = "SensorData"
  billing_mode   = "PROVISIONED"
  read_capacity  = var.dynamodb_read_capacity
  write_capacity = var.dynamodb_write_capacity

  hash_key  = "device_id"
  range_key = "timestamp"

  attribute {
    name = "device_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  # TTL configuration for automatic data cleanup
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name        = "SensorData"
    Description = "Stores power consumption data from IoT devices"
  }
} 