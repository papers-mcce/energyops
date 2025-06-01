#!/bin/bash

# Create DynamoDB table for EPEX Spot price data
aws dynamodb create-table \
  --table-name EPEXSpotPrices \
  --attribute-definitions \
      AttributeName=tariff,AttributeType=S \
      AttributeName=timestamp,AttributeType=N \
  --key-schema \
      AttributeName=tariff,KeyType=HASH \
      AttributeName=timestamp,KeyType=RANGE \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1

# Wait for table to be created
echo "Waiting for table to be created..."
aws dynamodb wait table-exists --table-name EPEXSpotPrices --region us-east-1

# Enable TTL on the table (optional - for automatic data cleanup after 1 year)
aws dynamodb update-time-to-live \
  --table-name EPEXSpotPrices \
  --time-to-live-specification Enabled=true,AttributeName=ttl \
  --region us-east-1

echo "EPEXSpotPrices table created successfully with TTL enabled!"
echo ""
echo "Table structure:"
echo "- Primary Key: tariff (HASH) + timestamp (RANGE)"
echo "- TTL: Enabled on 'ttl' attribute (1 year retention)"
echo ""
echo "Sample query commands:"
echo "# Get all prices for EPEXSPOTAT:"
echo "aws dynamodb query --table-name EPEXSpotPrices --key-condition-expression 'tariff = :tariff' --expression-attribute-values '{\":tariff\":{\"S\":\"EPEXSPOTAT\"}}' --region us-east-1"
echo ""
echo "# Get prices for a specific time range (last 24 hours):"
echo "TIMESTAMP=\$(date -d '24 hours ago' +%s)000"
echo "aws dynamodb query --table-name EPEXSpotPrices --key-condition-expression 'tariff = :tariff AND #ts > :timestamp' --expression-attribute-names '{\"#ts\":\"timestamp\"}' --expression-attribute-values '{\":tariff\":{\"S\":\"EPEXSPOTAT\"},\":timestamp\":{\"N\":\"'\$TIMESTAMP'\"}}' --region us-east-1" 