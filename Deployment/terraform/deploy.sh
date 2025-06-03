#!/bin/bash

# Energy Monitoring System - Terraform Deployment Script
# This script helps deploy the energy monitoring infrastructure on AWS

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check if AWS CLI is configured
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_success "All prerequisites are met!"
}

# Function to setup terraform.tfvars
setup_variables() {
    print_status "Setting up Terraform variables..."
    
    if [ ! -f "terraform.tfvars" ]; then
        if [ -f "terraform.tfvars.example" ]; then
            cp terraform.tfvars.example terraform.tfvars
            print_warning "Created terraform.tfvars from example file."
            print_warning "Please edit terraform.tfvars with your actual values before proceeding."
            echo ""
            echo "Required variables to update:"
            echo "  - energylive_api_key: Your energyLIVE API key"
            echo "  - energylive_device_uid: Your energyLIVE device UID"
            echo ""
            read -p "Press Enter after updating terraform.tfvars to continue..."
        else
            print_error "terraform.tfvars.example not found!"
            exit 1
        fi
    else
        print_success "terraform.tfvars already exists."
    fi
}

# Function to validate configuration
validate_config() {
    print_status "Validating configuration..."
    
    # Check if required variables are set
    if grep -q "your-energylive-api-key-here" terraform.tfvars 2>/dev/null; then
        print_error "Please update energylive_api_key in terraform.tfvars"
        exit 1
    fi
    
    print_success "Configuration validation passed!"
}

# Function to initialize Terraform
init_terraform() {
    print_status "Initializing Terraform..."
    terraform init
    print_success "Terraform initialized successfully!"
}

# Function to plan deployment
plan_deployment() {
    print_status "Creating deployment plan..."
    terraform plan -out=terraform.tfplan
    print_success "Deployment plan created!"
    
    echo ""
    print_warning "Please review the plan above carefully."
    read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled by user."
        exit 0
    fi
}

# Function to apply deployment
apply_deployment() {
    print_status "Applying deployment..."
    terraform apply terraform.tfplan
    print_success "Deployment completed successfully!"
}

# Function to show post-deployment information
show_post_deployment_info() {
    print_success "🚀 Energy Monitoring System deployed successfully!"
    echo ""
    
    print_status "Getting deployment outputs..."
    terraform output configuration_instructions
    
    echo ""
    print_warning "Important: Save your IoT certificates securely!"
    print_status "Run the following command to save IoT certificates:"
    echo "terraform output -json iot_resources > iot_certificates.json"
    
    echo ""
    print_status "Next steps:"
    echo "1. Update Lambda environment variables with your actual API credentials"
    echo "2. Test the Lambda functions"
    echo "3. Configure your NETIO PowerCable device"
    echo "4. Monitor data collection in CloudWatch and DynamoDB"
}

# Function to cleanup on error
cleanup_on_error() {
    print_error "Deployment failed!"
    if [ -f "terraform.tfplan" ]; then
        rm terraform.tfplan
        print_status "Cleaned up terraform plan file."
    fi
}

# Main deployment function
main() {
    echo ""
    echo "🔋 Energy Monitoring System - Terraform Deployment"
    echo "=================================================="
    echo ""
    
    # Set up error handling
    trap cleanup_on_error ERR
    
    # Run deployment steps
    check_prerequisites
    setup_variables
    validate_config
    init_terraform
    plan_deployment
    apply_deployment
    show_post_deployment_info
    
    echo ""
    print_success "Deployment script completed successfully!"
}

# Handle script arguments
case "${1:-}" in
    "init")
        check_prerequisites
        init_terraform
        ;;
    "plan")
        check_prerequisites
        validate_config
        terraform plan
        ;;
    "apply")
        check_prerequisites
        validate_config
        terraform apply
        ;;
    "destroy")
        print_warning "This will destroy all resources and delete all data!"
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            terraform destroy
        else
            print_status "Destroy cancelled."
        fi
        ;;
    "output")
        terraform output
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  (no args)  Run full deployment process"
        echo "  init       Initialize Terraform only"
        echo "  plan       Show deployment plan"
        echo "  apply      Apply deployment"
        echo "  destroy    Destroy all resources"
        echo "  output     Show deployment outputs"
        echo "  help       Show this help message"
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Run '$0 help' for usage information."
        exit 1
        ;;
esac 