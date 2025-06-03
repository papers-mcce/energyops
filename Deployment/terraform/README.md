# Energy Monitoring System - Terraform Deployment

This Terraform configuration deploys a complete serverless energy monitoring system on AWS that collects data from smart meters, IoT devices, and electricity price APIs.

## 🏗️ Architecture Overview

The deployment creates:

- **DynamoDB Tables**: Store energy consumption data, electricity prices, and IoT sensor data
- **Lambda Functions**: Collect data from APIs and process MQTT messages
- **IoT Core**: Manage NETIO PowerCable device connections
- **EventBridge**: Schedule automated data collection
- **IAM Roles & Policies**: Secure access control for all services
- **CloudWatch**: Logging and monitoring

## 📋 Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.0 installed
3. **energyLIVE API** credentials (API key and device UID)
4. **NETIO PowerCable** device (optional, for IoT functionality)

## 🚀 Quick Start

### 1. Clone and Navigate

```bash
cd Deployment/terraform
```

### 2. Configure Variables

Copy the example variables file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your actual values:

```hcl
# Required: energyLIVE API credentials
energylive_api_key    = "your-actual-api-key"
energylive_device_uid = "I-XXXXXXXX-XXXXXXXX"

# Optional: Customize other settings
aws_region    = "eu-central-1"
project_name  = "my-energy-monitoring"
environment   = "prod"
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Deploy the infrastructure
terraform apply
```

### 4. Save IoT Certificates

After deployment, save the IoT certificates for your NETIO device:

```bash
# Extract certificates (marked as sensitive output)
terraform output -json iot_resources > iot_certificates.json

# Or get them individually
terraform output -raw iot_resources
```

## 📊 Configuration Variables

| Variable                         | Description                    | Default              | Required |
| -------------------------------- | ------------------------------ | -------------------- | -------- |
| `aws_region`                     | AWS region for deployment      | `eu-central-1`       | No       |
| `environment`                    | Environment name               | `dev`                | No       |
| `project_name`                   | Project name prefix            | `energy-monitoring`  | No       |
| `energylive_api_key`             | energyLIVE API key             | `""`                 | **Yes**  |
| `energylive_device_uid`          | energyLIVE device UID          | `""`                 | **Yes**  |
| `lambda_timeout`                 | Lambda timeout (seconds)       | `60`                 | No       |
| `lambda_memory_size`             | Lambda memory (MB)             | `256`                | No       |
| `dynamodb_read_capacity`         | DynamoDB read capacity         | `5`                  | No       |
| `dynamodb_write_capacity`        | DynamoDB write capacity        | `5`                  | No       |
| `energylive_schedule_expression` | energyLIVE collection schedule | `rate(5 minutes)`    | No       |
| `epex_schedule_expression`       | EPEX price collection schedule | `rate(15 minutes)`   | No       |
| `iot_thing_name`                 | IoT Thing name                 | `netio-powercable-1` | No       |
| `iot_topic_name`                 | MQTT topic name                | `sensors/power/data` | No       |

## 🔐 IAM Permissions

The deployment creates the following IAM roles with minimal required permissions:

### Lambda Execution Role

- **Basic execution**: CloudWatch Logs access
- **DynamoDB access**: Read/write to energy monitoring tables
- **CloudWatch metrics**: Publish custom metrics

### IoT Role

- **Lambda invocation**: Trigger MQTT processor function

### EventBridge Role

- **Lambda invocation**: Trigger scheduled data collection

## 📊 DynamoDB Tables

### EnergyLiveData

- **Primary Key**: `device_id` (HASH) + `timestamp` (RANGE)
- **GSI**: `MeasurementTypeIndex` (measurement_type + timestamp)
- **TTL**: 1 year automatic cleanup
- **Capacity**: 10 RCU / 10 WCU (configurable)

### EPEXSpotPrices

- **Primary Key**: `tariff` (HASH) + `timestamp` (RANGE)
- **TTL**: 1 year automatic cleanup
- **Capacity**: 5 RCU / 5 WCU (configurable)

### SensorData

- **Primary Key**: `device_id` (HASH) + `timestamp` (RANGE)
- **TTL**: 1 year automatic cleanup
- **Capacity**: 5 RCU / 5 WCU (configurable)

## 🔧 Post-Deployment Configuration

### 1. Test Lambda Functions

```bash
# Test energyLIVE collector
aws lambda invoke \
  --function-name energy-monitoring-energylive-collector \
  --region eu-central-1 \
  output.json

# Test EPEX collector
aws lambda invoke \
  --function-name energy-monitoring-epex-collector \
  --region eu-central-1 \
  output.json
```

### 2. Configure NETIO PowerCable

Use the IoT certificates from the deployment output:

1. **MQTT Endpoint**: From `terraform output iot_resources`
2. **Topic**: `sensors/power/data` (or your custom topic)
3. **Certificates**: Use the PEM certificate and private key

### 3. Verify Data Collection

```bash
# Check energyLIVE data
aws dynamodb scan \
  --table-name EnergyLiveData \
  --limit 5 \
  --region eu-central-1

# Check EPEX price data
aws dynamodb scan \
  --table-name EPEXSpotPrices \
  --limit 5 \
  --region eu-central-1
```

## 📈 Monitoring

### CloudWatch Logs

- `/aws/lambda/energy-monitoring-energylive-collector`
- `/aws/lambda/energy-monitoring-epex-collector`
- `/aws/lambda/energy-monitoring-mqtt-processor`
- `/aws/iot/energy-monitoring`

### EventBridge Rules

- `energy-monitoring-energylive-schedule`: Every 5 minutes
- `energy-monitoring-epex-schedule`: Every 15 minutes

## 🛠️ Customization

### Modify Collection Schedules

```hcl
# In terraform.tfvars
energylive_schedule_expression = "rate(2 minutes)"  # More frequent
epex_schedule_expression = "rate(30 minutes)"       # Less frequent
```

### Scale DynamoDB Capacity

```hcl
# In terraform.tfvars
dynamodb_read_capacity  = 10
dynamodb_write_capacity = 10
```

### Change AWS Region

```hcl
# In terraform.tfvars
aws_region = "us-east-1"  # Or any other region
```

## 🧹 Cleanup

To destroy all resources:

```bash
terraform destroy
```

**⚠️ Warning**: This will permanently delete all data in DynamoDB tables.

## 🔍 Troubleshooting

### Common Issues

1. **Missing API credentials**: Ensure `energylive_api_key` and `energylive_device_uid` are set
2. **Lambda timeout**: Increase `lambda_timeout` if functions are timing out
3. **DynamoDB throttling**: Increase capacity units if you see throttling errors
4. **IoT connection issues**: Verify certificates and endpoint URL

### Debug Commands

```bash
# Check Lambda logs
aws logs tail /aws/lambda/energy-monitoring-energylive-collector --follow

# Test Lambda function locally
cd ../Lambda
python3 test_local.py

# Verify DynamoDB table status
aws dynamodb describe-table --table-name EnergyLiveData
```

## 📚 Additional Resources

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [DynamoDB Documentation](https://docs.aws.amazon.com/dynamodb/)
- [IoT Core Documentation](https://docs.aws.amazon.com/iot/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the deployment
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
