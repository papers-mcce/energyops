# PowerShell deployment script for energyLIVE Lambda function

# Configuration
$FUNCTION_NAME = "energylive-api-collector"
$REGION = "eu-central-1"
$ROLE_NAME = "energylive-lambda-role"

Write-Host "Deploying energyLIVE API Lambda function..." -ForegroundColor Yellow

# Check if AWS CLI is configured
try {
    aws sts get-caller-identity | Out-Null
} catch {
    Write-Host "Error: AWS CLI not configured. Please run 'aws configure' first." -ForegroundColor Red
    exit 1
}

# Get AWS account ID
$ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)
$ROLE_ARN = "arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

Write-Host "Using AWS Account: $ACCOUNT_ID"
Write-Host "Using Region: $REGION"

# Create IAM role if it doesn't exist
Write-Host "Creating IAM role..." -ForegroundColor Yellow

$trustPolicy = @"
{
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
}
"@

try {
    aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document $trustPolicy --region $REGION 2>$null
} catch {
    Write-Host "Role already exists"
}

# Attach basic Lambda execution policy
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

# Create and attach DynamoDB policy
$dynamoPolicy = @"
{
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
                "arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/EnergyLiveData",
                "arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/EnergyLiveData/index/*"
            ]
        }
    ]
}
"@

aws iam put-role-policy --role-name $ROLE_NAME --policy-name "DynamoDBAccess" --policy-document $dynamoPolicy

Write-Host "Waiting for IAM role to propagate..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Create deployment package
Write-Host "Creating deployment package..." -ForegroundColor Yellow

if (Test-Path "energylive-lambda.zip") {
    Remove-Item "energylive-lambda.zip"
}

# Install dependencies in a temporary directory
if (Test-Path "package") {
    Remove-Item -Recurse -Force "package"
}
New-Item -ItemType Directory -Name "package" | Out-Null

pip install -r requirements.txt -t package/

# Copy Lambda function
Copy-Item "energylive-api-collector.py" "package/"

# Create zip file
Compress-Archive -Path "package/*" -DestinationPath "energylive-lambda.zip"

# Clean up
Remove-Item -Recurse -Force "package"

# Deploy Lambda function
Write-Host "Deploying Lambda function..." -ForegroundColor Yellow

# Check if function exists
try {
    aws lambda get-function --function-name $FUNCTION_NAME --region $REGION 2>$null
    $functionExists = $true
} catch {
    $functionExists = $false
}

if ($functionExists) {
    Write-Host "Function exists, updating..."
    aws lambda update-function-code --function-name $FUNCTION_NAME --zip-file "fileb://energylive-lambda.zip" --region $REGION
    
    aws lambda update-function-configuration --function-name $FUNCTION_NAME --timeout 60 --memory-size 256 --environment "Variables={API_KEY=YOUR_API_KEY_HERE,DEVICE_UID=I-XXXXXXXX-XXXXXXXX}" --region $REGION
} else {
    Write-Host "Creating new function..."
    aws lambda create-function --function-name $FUNCTION_NAME --runtime python3.9 --role $ROLE_ARN --handler "energylive-api-collector.lambda_handler" --zip-file "fileb://energylive-lambda.zip" --timeout 60 --memory-size 256 --environment "Variables={API_KEY=YOUR_API_KEY_HERE,DEVICE_UID=I-XXXXXXXX-XXXXXXXX}" --region $REGION
}

# Clean up zip file
Remove-Item "energylive-lambda.zip"

Write-Host "Lambda function deployed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT: Update environment variables" -ForegroundColor Yellow
Write-Host "1. Go to AWS Lambda console"
Write-Host "2. Find function: $FUNCTION_NAME"
Write-Host "3. Update environment variables:"
Write-Host "   - API_KEY: Your energyLIVE API key"
Write-Host "   - DEVICE_UID: Your device UID (e.g., I-10082023-01658401)"
Write-Host ""
Write-Host "To test the function:" -ForegroundColor Yellow
Write-Host "aws lambda invoke --function-name $FUNCTION_NAME --region $REGION output.json"
Write-Host ""
Write-Host "To set up scheduled execution (every 5 minutes):" -ForegroundColor Yellow
Write-Host "aws events put-rule --name energylive-schedule --schedule-expression 'rate(5 minutes)' --region $REGION"
Write-Host "aws lambda add-permission --function-name $FUNCTION_NAME --statement-id energylive-schedule --action lambda:InvokeFunction --principal events.amazonaws.com --source-arn arn:aws:events:${REGION}:${ACCOUNT_ID}:rule/energylive-schedule --region $REGION"
Write-Host "aws events put-targets --rule energylive-schedule --targets Id=1,Arn=arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:${FUNCTION_NAME} --region $REGION" 