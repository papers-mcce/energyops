# energyLIVE API Lambda Function

This Lambda function collects energy measurement data from the energyLIVE API and stores it in Amazon DynamoDB.

## Overview

The function fetches the latest measurements from a Sagemcom Smart Meter via the energyLIVE API and stores the data in a structured format in DynamoDB. It handles various measurement types including OBIS codes for electrical measurements and battery voltage data.

## Architecture

```
energyLIVE API → Lambda Function → DynamoDB
                      ↓
                CloudWatch Logs
```

## Files

- `energylive-api-collector.py` - Main Lambda function code
- `requirements.txt` - Python dependencies
- `deploy-energylive-lambda.bash` - Deployment script
- `../DynamoDB/createEnergyLiveTable.bash` - DynamoDB table creation script

## Prerequisites

1. AWS CLI configured with appropriate permissions
2. Python 3.9+ (for local testing)
3. energyLIVE API key
4. Device UID from energyLIVE portal

## Setup Instructions

### 1. Create DynamoDB Table

First, create the DynamoDB table to store the energy data:

```bash
cd ../DynamoDB
chmod +x createEnergyLiveTable.bash
./createEnergyLiveTable.bash
```

### 2. Deploy Lambda Function

```bash
chmod +x deploy-energylive-lambda.bash
./deploy-energylive-lambda.bash
```

### 3. Configure Environment Variables

After deployment, update the Lambda function's environment variables:

1. Go to AWS Lambda Console
2. Find the function `energylive-api-collector`
3. Go to Configuration → Environment variables
4. Update:
   - `API_KEY`: Your energyLIVE API key (e.g., `VsMgAMu7D6SD7jXEzbDlw_16KUn5I4XziIxki8kGPQk`)
   - `DEVICE_UID`: Your device UID (e.g., `I-10082023-01658401`)

### 4. Test the Function

Test the function manually:

```bash
aws lambda invoke \
  --function-name energylive-api-collector \
  --region eu-central-1 \
  output.json

cat output.json
```

### 5. Set Up Scheduled Execution (Optional)

To automatically collect data every 5 minutes:

```bash
# Create EventBridge rule
aws events put-rule \
  --name energylive-schedule \
  --schedule-expression 'rate(5 minutes)' \
  --region eu-central-1

# Add permission for EventBridge to invoke Lambda
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws lambda add-permission \
  --function-name energylive-api-collector \
  --statement-id energylive-schedule \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:eu-central-1:$ACCOUNT_ID:rule/energylive-schedule \
  --region eu-central-1

# Add Lambda as target for the rule
aws events put-targets \
  --rule energylive-schedule \
  --targets Id=1,Arn=arn:aws:lambda:eu-central-1:$ACCOUNT_ID:function:energylive-api-collector \
  --region eu-central-1
```

## Data Structure

The function stores data in DynamoDB with the following structure:

```json
{
  "device_id": "I-10082023-01658401",
  "timestamp": 1726559995000,
  "iso_timestamp": "2024-09-17T10:33:15",
  "measurement_type": "0100010700",
  "value": 138.0,
  "collection_time": "2024-09-17T10:35:00.123456",
  "ttl": 1757095995
}
```

### Measurement Types

Common OBIS codes you'll see:

- `0100010700`: Current power consumption (W)
- `0100010800`: Total energy consumption (Wh)
- `0100020700`: Current power generation (W)
- `0100020800`: Total energy generation (Wh)
- `batteryVoltage`: Battery voltage of the smart meter

## Querying Data

### Get all measurements for a device:

```bash
aws dynamodb query \
  --table-name EnergyLiveData \
  --key-condition-expression 'device_id = :device_id' \
  --expression-attribute-values '{":device_id":{"S":"I-10082023-01658401"}}' \
  --region eu-central-1
```

### Get specific measurement type:

```bash
aws dynamodb query \
  --table-name EnergyLiveData \
  --index-name MeasurementTypeIndex \
  --key-condition-expression 'measurement_type = :measurement_type' \
  --expression-attribute-values '{":measurement_type":{"S":"0100010700"}}' \
  --region eu-central-1
```

### Get recent measurements (last hour):

```bash
TIMESTAMP=$(date -d '1 hour ago' +%s)000
aws dynamodb query \
  --table-name EnergyLiveData \
  --key-condition-expression 'device_id = :device_id AND #ts > :timestamp' \
  --expression-attribute-names '{"#ts":"timestamp"}' \
  --expression-attribute-values '{":device_id":{"S":"I-10082023-01658401"},":timestamp":{"N":"'$TIMESTAMP'"}}' \
  --region eu-central-1
```

## Monitoring

### CloudWatch Logs

View function logs:

```bash
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/energylive-api-collector
aws logs tail /aws/lambda/energylive-api-collector --follow
```

### CloudWatch Metrics

Key metrics to monitor:

- `Duration`: Function execution time
- `Errors`: Number of failed executions
- `Invocations`: Total number of executions
- `Throttles`: Number of throttled executions

## Troubleshooting

### Common Issues

1. **API Key Invalid**

   - Verify the API key in environment variables
   - Check if the key has expired

2. **Device UID Not Found**

   - Verify the device UID in the energyLIVE portal
   - Ensure the format is correct (I-XXXXXXXX-XXXXXXXX)

3. **DynamoDB Access Denied**

   - Check IAM role permissions
   - Verify the table exists and is in the correct region

4. **Timeout Errors**
   - Increase Lambda timeout (currently set to 60 seconds)
   - Check network connectivity

### Debug Mode

To enable debug logging, add this environment variable:

- `DEBUG`: `true`

## Cost Optimization

- **DynamoDB**: Uses on-demand billing by default
- **Lambda**: Free tier covers up to 1M requests/month
- **TTL**: Automatically deletes data after 1 year to control storage costs

## Security

- API key stored as environment variable (consider using AWS Secrets Manager for production)
- IAM role follows principle of least privilege
- VPC deployment not required for this use case

## Integration with QuickSight

To visualize this data in Amazon QuickSight:

1. Create a new dataset in QuickSight
2. Choose DynamoDB as data source
3. Select the `EnergyLiveData` table
4. Create visualizations based on:
   - Power consumption over time
   - Energy usage by measurement type
   - Device comparison (if multiple devices)

## Next Steps

1. Set up alerting for high energy consumption
2. Create automated reports
3. Integrate with other energy data sources
4. Implement data aggregation for historical analysis
