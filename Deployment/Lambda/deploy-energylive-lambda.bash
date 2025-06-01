#!/bin/bash

# Configuration
FUNCTION_NAME="energylive-api-collector"
REGION="eu-central-1"
ROLE_NAME="energylive-lambda-role"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Deploying energyLIVE API Lambda function...${NC}"

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS CLI not configured. Please run 'aws configure' first.${NC}"
    exit 1
fi

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

echo "Using AWS Account: $ACCOUNT_ID"
echo "Using Region: $REGION"

# Create IAM role if it doesn't exist
echo -e "${YELLOW}Creating IAM role...${NC}"
aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "lambda.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }' \
    --region $REGION 2>/dev/null || echo "Role already exists"

# Attach basic Lambda execution policy
aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Create and attach DynamoDB policy
aws iam put-role-policy \
    --role-name $ROLE_NAME \
    --policy-name DynamoDBAccess \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "dynamodb:PutItem",
                    "dynamodb:GetItem",
                    "dynamodb:UpdateItem",
                    "dynamodb:DeleteItem",
                    "dynamodb:Query",
                    "dynamodb:Scan"
                ],
                "Resource": [
                    "arn:aws:dynamodb:'$REGION':'$ACCOUNT_ID':table/EnergyLiveData",
                    "arn:aws:dynamodb:'$REGION':'$ACCOUNT_ID':table/EnergyLiveData/index/*"
                ]
            }
        ]
    }'

echo -e "${YELLOW}Waiting for IAM role to propagate...${NC}"
sleep 10

# Create deployment package
echo -e "${YELLOW}Creating deployment package...${NC}"
rm -f energylive-lambda.zip

# Install dependencies in a temporary directory
mkdir -p package
pip install -r requirements.txt -t package/

# Copy Lambda function
cp energylive-api-collector.py package/

# Create zip file
cd package
zip -r ../energylive-lambda.zip .
cd ..

# Clean up
rm -rf package

# Deploy Lambda function
echo -e "${YELLOW}Deploying Lambda function...${NC}"

# Check if function exists
if aws lambda get-function --function-name $FUNCTION_NAME --region $REGION &> /dev/null; then
    echo "Function exists, updating..."
    aws lambda update-function-code \
        --function-name $FUNCTION_NAME \
        --zip-file fileb://energylive-lambda.zip \
        --region $REGION
    
    aws lambda update-function-configuration \
        --function-name $FUNCTION_NAME \
        --timeout 60 \
        --memory-size 256 \
        --environment Variables='{API_KEY=YOUR_API_KEY_HERE,DEVICE_UID=I-XXXXXXXX-XXXXXXXX}' \
        --region $REGION
else
    echo "Creating new function..."
    aws lambda create-function \
        --function-name $FUNCTION_NAME \
        --runtime python3.9 \
        --role $ROLE_ARN \
        --handler energylive-api-collector.lambda_handler \
        --zip-file fileb://energylive-lambda.zip \
        --timeout 60 \
        --memory-size 256 \
        --environment Variables='{API_KEY=YOUR_API_KEY_HERE,DEVICE_UID=I-XXXXXXXX-XXXXXXXX}' \
        --region $REGION
fi

# Clean up zip file
rm energylive-lambda.zip

echo -e "${GREEN}Lambda function deployed successfully!${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT: Update environment variables${NC}"
echo "1. Go to AWS Lambda console"
echo "2. Find function: $FUNCTION_NAME"
echo "3. Update environment variables:"
echo "   - API_KEY: Your energyLIVE API key"
echo "   - DEVICE_UID: Your device UID (e.g., I-10082023-01658401)"
echo ""
echo -e "${YELLOW}To test the function:${NC}"
echo "aws lambda invoke --function-name $FUNCTION_NAME --region $REGION output.json"
echo ""
echo -e "${YELLOW}To set up scheduled execution (every 5 minutes):${NC}"
echo "aws events put-rule --name energylive-schedule --schedule-expression 'rate(5 minutes)' --region $REGION"
echo "aws lambda add-permission --function-name $FUNCTION_NAME --statement-id energylive-schedule --action lambda:InvokeFunction --principal events.amazonaws.com --source-arn arn:aws:events:$REGION:$ACCOUNT_ID:rule/energylive-schedule --region $REGION"
echo "aws events put-targets --rule energylive-schedule --targets Id=1,Arn=arn:aws:lambda:$REGION:$ACCOUNT_ID:function:$FUNCTION_NAME --region $REGION" 