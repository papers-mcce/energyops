# AWS Academy Learner Lab Deployment Guide

This guide is specifically for deploying the energy monitoring Lambda functions in AWS Academy Learner Lab.

## 🎓 Prerequisites

1. **Active Learner Lab session** (green AWS icon)
2. **WSL or Linux terminal** with AWS CLI configured
3. **energyLIVE API credentials** (API key and Device UID)

## 🚀 Quick Deployment Steps

### Step 1: Configure AWS CLI

```bash
# Get credentials from AWS Details in Learner Lab
aws configure
# Enter your credentials from the lab

# Set session token (required for Learner Lab)
export AWS_SESSION_TOKEN="your-session-token-from-aws-details"
```

### Step 2: Deploy DynamoDB Tables

```bash
cd /mnt/c/Users/dkl/Desktop/FH/2.\ Semester/G1-S2-INENI/Deployment/DynamoDB

# Create EnergyLive table
chmod +x createEnergyLiveTable.bash
./createEnergyLiveTable.bash

# Create EPEX Spot table
chmod +x createEPEXSpotTable.bash
./createEPEXSpotTable.bash
```

### Step 3: Deploy Lambda Functions

```bash
cd ../Lambda

# Deploy energyLIVE collector
chmod +x deploy-energylive-lambda.bash
./deploy-energylive-lambda.bash

# Deploy EPEX Spot collector
chmod +x deploy-epex-lambda.bash
./deploy-epex-lambda.bash
```

### Step 4: Configure energyLIVE Function

```bash
# Update with your actual credentials
aws lambda update-function-configuration \
  --function-name energylive-api-collector \
  --environment Variables='{API_KEY=YOUR_ACTUAL_API_KEY,DEVICE_UID=YOUR_ACTUAL_DEVICE_UID}' \
  --region us-east-1
```

### Step 5: Test Functions

```bash
# Test energyLIVE function
aws lambda invoke \
  --function-name energylive-api-collector \
  --region us-east-1 \
  output-energy.json

cat output-energy.json

# Test EPEX function
aws lambda invoke \
  --function-name epex-spot-collector \
  --region us-east-1 \
  output-epex.json

cat output-epex.json
```

## 🔍 Verify Data

### Check EnergyLive Data

```bash
aws dynamodb scan \
  --table-name EnergyLiveData \
  --limit 3 \
  --region us-east-1
```

### Check EPEX Data

```bash
aws dynamodb scan \
  --table-name EPEXSpotPrices \
  --limit 3 \
  --region us-east-1
```

## ⏰ Set Up Automatic Collection

### EnergyLive (Every 5 minutes)

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws events put-rule \
  --name energylive-schedule \
  --schedule-expression 'rate(5 minutes)' \
  --region us-east-1

aws lambda add-permission \
  --function-name energylive-api-collector \
  --statement-id energylive-schedule \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:us-east-1:$ACCOUNT_ID:rule/energylive-schedule \
  --region us-east-1

aws events put-targets \
  --rule energylive-schedule \
  --targets Id=1,Arn=arn:aws:lambda:us-east-1:$ACCOUNT_ID:function:energylive-api-collector \
  --region us-east-1
```

### EPEX Spot (Every 15 minutes)

```bash
aws events put-rule \
  --name epex-schedule \
  --schedule-expression 'rate(15 minutes)' \
  --region us-east-1

aws lambda add-permission \
  --function-name epex-spot-collector \
  --statement-id epex-schedule \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:us-east-1:$ACCOUNT_ID:rule/epex-schedule \
  --region us-east-1

aws events put-targets \
  --rule epex-schedule \
  --targets Id=1,Arn=arn:aws:lambda:us-east-1:$ACCOUNT_ID:function:epex-spot-collector \
  --region us-east-1
```

## 🎯 Key Differences from Production

1. **Uses LabRole** - No custom IAM roles needed
2. **Session Tokens** - Required for Learner Lab authentication
3. **us-east-1 Region** - Learner Lab default region
4. **No IAM Management** - All permissions handled by LabRole

## 🔧 Troubleshooting

### Session Expired

If you get authentication errors:

1. Restart your Learner Lab session
2. Get new credentials from "AWS Details"
3. Run `aws configure` again
4. Set new session token: `export AWS_SESSION_TOKEN="new-token"`

### Function Not Found

If Lambda functions don't exist, deploy them manually via AWS Console:

1. Go to Lambda Console
2. Create function with Python 3.9 runtime
3. Use LabRole as execution role
4. Upload the zip files created by the scripts

## 📊 Expected Results

- **EnergyLive**: Collects smart meter data every 5 minutes
- **EPEX Spot**: Collects electricity prices every 15 minutes
- **Data Storage**: Both stored in DynamoDB with 1-year TTL
- **Cost**: Minimal within Learner Lab limits

## 🎉 Success Indicators

✅ Both Lambda functions deployed successfully  
✅ DynamoDB tables created with data  
✅ CloudWatch logs show successful executions  
✅ No authentication errors  
✅ Data visible in AWS Console
