# Quick Start Guide: energyLIVE API Lambda Function

This guide will help you quickly deploy a Lambda function that collects data from the energyLIVE API and stores it in DynamoDB.

## Prerequisites

1. **AWS CLI** configured with appropriate permissions
2. **Python 3.9+** installed
3. **energyLIVE API credentials**:
   - API Key (e.g., `VsMgAMu7D6SD7jXEzbDlw_16KUn5I4XziIxki8kGPQk`)
   - Device UID (e.g., `I-10082023-01658401`)

## 🚀 Quick Deployment (Windows PowerShell)

### Step 1: Create DynamoDB Table

```powershell
cd Deployment/DynamoDB
.\createEnergyLiveTable.ps1
```

### Step 2: Deploy Lambda Function

```powershell
cd ../Lambda
.\deploy-energylive-lambda.ps1
```

### Step 3: Configure Environment Variables

1. Go to [AWS Lambda Console](https://console.aws.amazon.com/lambda/)
2. Find function: `energylive-api-collector`
3. Go to **Configuration** → **Environment variables**
4. Update:
   - `API_KEY`: Your energyLIVE API key
   - `DEVICE_UID`: Your device UID

### Step 4: Test the Function

```powershell
aws lambda invoke --function-name energylive-api-collector --region eu-central-1 output.json
Get-Content output.json
```

## 🐧 Quick Deployment (Linux/macOS)

### Step 1: Create DynamoDB Table

```bash
cd Deployment/DynamoDB
chmod +x createEnergyLiveTable.bash
./createEnergyLiveTable.bash
```

### Step 2: Deploy Lambda Function

```bash
cd ../Lambda
chmod +x deploy-energylive-lambda.bash
./deploy-energylive-lambda.bash
```

### Step 3: Configure Environment Variables

Same as Windows - use AWS Console or CLI:

```bash
aws lambda update-function-configuration \
  --function-name energylive-api-collector \
  --environment Variables='{API_KEY=YOUR_ACTUAL_API_KEY,DEVICE_UID=YOUR_ACTUAL_DEVICE_UID}' \
  --region eu-central-1
```

### Step 4: Test the Function

```bash
aws lambda invoke --function-name energylive-api-collector --region eu-central-1 output.json
cat output.json
```

## 📊 Expected Output

Successful execution should return:

```json
{
  "statusCode": 200,
  "body": "{\"message\": \"Successfully processed 4 measurements\", \"device_id\": \"I-10082023-01658401\", \"measurements_processed\": 4}"
}
```

## ⏰ Set Up Automatic Collection (Every 5 Minutes)

```bash
# Create EventBridge rule
aws events put-rule \
  --name energylive-schedule \
  --schedule-expression 'rate(5 minutes)' \
  --region eu-central-1

# Get your AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Add permission for EventBridge to invoke Lambda
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

## 🔍 Verify Data in DynamoDB

### View all measurements for your device:

```bash
aws dynamodb query \
  --table-name EnergyLiveData \
  --key-condition-expression 'device_id = :device_id' \
  --expression-attribute-values '{":device_id":{"S":"I-10082023-01658401"}}' \
  --region eu-central-1
```

### View specific measurement type (e.g., current power):

```bash
aws dynamodb query \
  --table-name EnergyLiveData \
  --index-name MeasurementTypeIndex \
  --key-condition-expression 'measurement_type = :measurement_type' \
  --expression-attribute-values '{":measurement_type":{"S":"0100010700"}}' \
  --region eu-central-1
```

## 📈 Data Structure

Each measurement is stored with this structure:

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

### Common Measurement Types:

- `0100010700`: Current power consumption (W)
- `0100010800`: Total energy consumption (Wh)
- `0100020700`: Current power generation (W)
- `0100020800`: Total energy generation (Wh)
- `batteryVoltage`: Smart meter battery voltage

## 🛠️ Troubleshooting

### Function fails with "API Key Invalid"

- Verify your API key in the Lambda environment variables
- Check if the key has expired in the energyLIVE portal

### Function fails with "Device UID Not Found"

- Verify the device UID format: `I-XXXXXXXX-XXXXXXXX`
- Check the device UID in your energyLIVE portal

### No data in DynamoDB

- Check CloudWatch logs: `/aws/lambda/energylive-api-collector`
- Verify IAM permissions for DynamoDB access
- Test the function manually first

### View CloudWatch Logs:

```bash
aws logs tail /aws/lambda/energylive-api-collector --follow --region eu-central-1
```

## 💰 Cost Estimation

- **Lambda**: ~$0.20/month (1M requests in free tier)
- **DynamoDB**: ~$1-5/month (depending on data volume)
- **CloudWatch**: ~$0.50/month for logs

## 🔗 Integration with QuickSight

1. Open [Amazon QuickSight](https://quicksight.aws.amazon.com/)
2. Create new dataset → DynamoDB → `EnergyLiveData`
3. Create visualizations for:
   - Power consumption over time
   - Energy usage by measurement type
   - Device comparison

## 📚 Additional Resources

- [Full Documentation](Lambda/README.md)
- [AWS Lambda Console](https://console.aws.amazon.com/lambda/)
- [DynamoDB Console](https://console.aws.amazon.com/dynamodb/)
- [CloudWatch Logs](https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups)

---

**Need help?** Check the detailed [README](Lambda/README.md) or review the CloudWatch logs for error details.
