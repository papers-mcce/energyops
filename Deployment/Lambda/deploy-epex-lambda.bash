#!/bin/bash

# Configuration
FUNCTION_NAME="epex-spot-collector"
REGION="us-east-1"
ROLE_NAME="LabRole"  # Using existing LabRole for AWS Academy

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Deploying EPEX Spot price Lambda function...${NC}"

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
echo "Using Role: $ROLE_ARN"

# Create deployment package
echo -e "${YELLOW}Creating deployment package...${NC}"
rm -f epex-lambda.zip

# Install dependencies in a temporary directory
mkdir -p package
pip3 install -r requirements.txt -t package/
pip3 install python-dateutil -t package/

# Copy Lambda function
cp epex-spot-collector.py package/

# Create zip file
cd package
zip -r ../epex-lambda.zip .
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
        --zip-file fileb://epex-lambda.zip \
        --region $REGION
    
    aws lambda update-function-configuration \
        --function-name $FUNCTION_NAME \
        --timeout 60 \
        --memory-size 256 \
        --region $REGION
else
    echo "Creating new function..."
    aws lambda create-function \
        --function-name $FUNCTION_NAME \
        --runtime python3.9 \
        --role $ROLE_ARN \
        --handler epex-spot-collector.lambda_handler \
        --zip-file fileb://epex-lambda.zip \
        --timeout 60 \
        --memory-size 256 \
        --region $REGION
fi

# Clean up zip file
rm epex-lambda.zip

echo -e "${GREEN}Lambda function deployed successfully!${NC}"
echo ""
echo -e "${YELLOW}No environment variables needed - the smartENERGY API is free and public!${NC}"
echo ""
echo -e "${YELLOW}To test the function:${NC}"
echo "aws lambda invoke --function-name $FUNCTION_NAME --region $REGION output.json"
echo ""
echo -e "${YELLOW}To set up scheduled execution (every 15 minutes):${NC}"
echo "aws events put-rule --name epex-schedule --schedule-expression 'rate(15 minutes)' --region $REGION"
echo "aws lambda add-permission --function-name $FUNCTION_NAME --statement-id epex-schedule --action lambda:InvokeFunction --principal events.amazonaws.com --source-arn arn:aws:events:$REGION:$ACCOUNT_ID:rule/epex-schedule --region $REGION"
echo "aws events put-targets --rule epex-schedule --targets Id=1,Arn=arn:aws:lambda:$REGION:$ACCOUNT_ID:function:$FUNCTION_NAME --region $REGION" 