#!/bin/bash

# Create DynamoDB table for energyLIVE data
aws dynamodb create-table \
  --table-name EnergyLiveData \
  --attribute-definitions \
      AttributeName=device_id,AttributeType=S \
      AttributeName=timestamp,AttributeType=N \
      AttributeName=measurement_type,AttributeType=S \
  --key-schema \
      AttributeName=device_id,KeyType=HASH \
      AttributeName=timestamp,KeyType=RANGE \
  --global-secondary-indexes \
      '[{
        "IndexName": "MeasurementTypeIndex",
        "KeySchema": [
          {
            "AttributeName": "measurement_type",
            "KeyType": "HASH"
          },
          {
            "AttributeName": "timestamp",
            "KeyType": "RANGE"
          }
        ],
        "Projection": {
          "ProjectionType": "ALL"
        },
        "ProvisionedThroughput": {
          "ReadCapacityUnits": 5,
          "WriteCapacityUnits": 5
        }
      }]' \
  --provisioned-throughput ReadCapacityUnits=10,WriteCapacityUnits=10 \
  --region us-east-1

# Wait for table to be created
echo "Waiting for table to be created..."
aws dynamodb wait table-exists --table-name EnergyLiveData --region us-east-1

# Enable TTL on the table (optional - for automatic data cleanup after 1 year)
aws dynamodb update-time-to-live \
  --table-name EnergyLiveData \
  --time-to-live-specification Enabled=true,AttributeName=ttl \
  --region us-east-1

echo "EnergyLiveData table created successfully with TTL enabled!"
echo ""
echo "Table structure:"
echo "- Primary Key: device_id (HASH) + timestamp (RANGE)"
echo "- Global Secondary Index: MeasurementTypeIndex (measurement_type + timestamp)"
echo "- TTL: Enabled on 'ttl' attribute (1 year retention)"
echo ""
echo "Sample query commands:"
echo "# Get all measurements for a device:"
echo "aws dynamodb query --table-name EnergyLiveData --key-condition-expression 'device_id = :device_id' --expression-attribute-values '{\":device_id\":{\"S\":\"I-10082023-01658401\"}}' --region us-east-1"
echo ""
echo "# Get specific measurement type across all devices:"
echo "aws dynamodb query --table-name EnergyLiveData --index-name MeasurementTypeIndex --key-condition-expression 'measurement_type = :measurement_type' --expression-attribute-values '{\":measurement_type\":{\"S\":\"0100010700\"}}' --region us-east-1"