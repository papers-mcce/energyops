# PowerShell script to create DynamoDB table for energyLIVE data

$REGION = "eu-central-1"
$TABLE_NAME = "EnergyLiveData"

Write-Host "Creating DynamoDB table for energyLIVE data..." -ForegroundColor Yellow

# Create DynamoDB table
aws dynamodb create-table `
  --table-name $TABLE_NAME `
  --attribute-definitions `
      AttributeName=device_id,AttributeType=S `
      AttributeName=timestamp,AttributeType=N `
      AttributeName=measurement_type,AttributeType=S `
  --key-schema `
      AttributeName=device_id,KeyType=HASH `
      AttributeName=timestamp,KeyType=RANGE `
  --global-secondary-indexes `
      "IndexName=MeasurementTypeIndex,KeySchema=[{AttributeName=measurement_type,KeyType=HASH},{AttributeName=timestamp,KeyType=RANGE}],Projection={ProjectionType=ALL},ProvisionedThroughput={ReadCapacityUnits=5,WriteCapacityUnits=5}" `
  --provisioned-throughput ReadCapacityUnits=10,WriteCapacityUnits=10 `
  --region $REGION

# Wait for table to be created
Write-Host "Waiting for table to be created..." -ForegroundColor Yellow
aws dynamodb wait table-exists --table-name $TABLE_NAME --region $REGION

# Enable TTL on the table (optional - for automatic data cleanup after 1 year)
Write-Host "Enabling TTL..." -ForegroundColor Yellow
aws dynamodb update-time-to-live `
  --table-name $TABLE_NAME `
  --time-to-live-specification Enabled=true,AttributeName=ttl `
  --region $REGION

Write-Host "$TABLE_NAME table created successfully with TTL enabled!" -ForegroundColor Green
Write-Host ""
Write-Host "Table structure:" -ForegroundColor Yellow
Write-Host "- Primary Key: device_id (HASH) + timestamp (RANGE)"
Write-Host "- Global Secondary Index: MeasurementTypeIndex (measurement_type + timestamp)"
Write-Host "- TTL: Enabled on 'ttl' attribute (1 year retention)"
Write-Host ""
Write-Host "Sample query commands:" -ForegroundColor Yellow
Write-Host "# Get all measurements for a device:"
Write-Host 'aws dynamodb query --table-name EnergyLiveData --key-condition-expression "device_id = :device_id" --expression-attribute-values "{\":device_id\":{\"S\":\"I-10082023-01658401\"}}"'
Write-Host ""
Write-Host "# Get specific measurement type across all devices:"
Write-Host 'aws dynamodb query --table-name EnergyLiveData --index-name MeasurementTypeIndex --key-condition-expression "measurement_type = :measurement_type" --expression-attribute-values "{\":measurement_type\":{\"S\":\"0100010700\"}}"' 