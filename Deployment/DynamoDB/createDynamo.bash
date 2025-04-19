aws dynamodb create-table \
  --table-name SensorData \
  --attribute-definitions \
      AttributeName=device_id,AttributeType=S \
      AttributeName=timestamp,AttributeType=S \
  --key-schema \
      AttributeName=device_id,KeyType=HASH \
      AttributeName=timestamp,KeyType=RANGE \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5