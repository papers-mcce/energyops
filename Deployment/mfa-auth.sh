#!/usr/bin/bash

# MFA Authentication Script for AWS
# This script gets temporary credentials using MFA and outputs them for sourcing

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MFA_SERIAL_NUMBER="arn:aws:iam::935822490870:mfa/Samsung-A55-Pruggi"
SESSION_DURATION=3600  # 1 hour (3600 seconds)

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Function to clear expired AWS credentials
clear_expired_credentials() {
    print_status "Clearing any expired AWS credentials..."
    
    # Check if we have temporary credentials that might be expired
    if [ -n "$AWS_SESSION_TOKEN" ] || [ -n "$AWS_ACCESS_KEY_ID" ] || [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
        print_warning "Found temporary AWS credentials in environment."
        print_status "Clearing them to prevent authentication conflicts..."
        
        # Clear the environment variables
        unset AWS_SESSION_TOKEN
        unset AWS_ACCESS_KEY_ID
        unset AWS_SECRET_ACCESS_KEY
        
        print_success "✅ Cleared temporary credentials."
        echo "" >&2
    else
        print_status "No temporary credentials found in environment."
        echo "" >&2
    fi
}

# Function to check if AWS CLI is configured
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if AWS CLI has basic configuration
    if ! aws configure list &> /dev/null; then
        print_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    # Try to get caller identity, but don't fail if credentials are expired
    if ! aws sts get-caller-identity &> /dev/null; then
        print_warning "AWS credentials appear to be expired or invalid."
        print_status "This is normal if your MFA session has expired."
        print_status "Continuing with MFA authentication..."
        echo "" >&2
    else
        CURRENT_USER=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null || echo "Unknown")
        print_status "Current AWS Identity: $CURRENT_USER"
        echo "" >&2
    fi
}

# Function to get MFA token
get_mfa_token() {
    print_status "🔐 AWS MFA Authentication" >&2
    echo "==========================================" >&2
    echo "" >&2
    
    # Show MFA device info
    print_status "MFA Device: $MFA_SERIAL_NUMBER"
    echo "" >&2
    
    # Prompt for MFA code
    read -p "Enter your 6-digit MFA code: " MFA_CODE >&2
    
    if [[ ! $MFA_CODE =~ ^[0-9]{6}$ ]]; then
        print_error "Invalid MFA code format. Please enter a 6-digit number."
        exit 1
    fi
    
    print_status "Getting temporary credentials..."
    
    # Get session token with timeout
    print_status "Calling AWS STS (this may take a few seconds)..."
    
    # Use timeout to prevent hanging
    CREDENTIALS=$(timeout 30 aws sts get-session-token \
        --serial-number "$MFA_SERIAL_NUMBER" \
        --token-code "$MFA_CODE" \
        --duration-seconds "$SESSION_DURATION" \
        --output json 2>&1)
    
    TIMEOUT_EXIT_CODE=$?
    
    if [ $TIMEOUT_EXIT_CODE -eq 124 ]; then
        print_error "Request timed out after 30 seconds. Please check your internet connection and try again."
        exit 1
    fi
    
    if [ $TIMEOUT_EXIT_CODE -ne 0 ]; then
        print_error "Failed to get session token. Error:"
        echo "$CREDENTIALS" >&2
        print_error "Please check your MFA code and try again."
        exit 1
    fi
    
    # Extract credentials
    ACCESS_KEY=$(echo "$CREDENTIALS" | jq -r '.Credentials.AccessKeyId')
    SECRET_KEY=$(echo "$CREDENTIALS" | jq -r '.Credentials.SecretAccessKey')
    SESSION_TOKEN=$(echo "$CREDENTIALS" | jq -r '.Credentials.SessionToken')
    EXPIRATION=$(echo "$CREDENTIALS" | jq -r '.Credentials.Expiration')
    
    if [ "$ACCESS_KEY" = "null" ] || [ "$SECRET_KEY" = "null" ] || [ "$SESSION_TOKEN" = "null" ]; then
        print_error "Failed to parse credentials from AWS response."
        print_error "Response was:"
        echo "$CREDENTIALS" >&2
        exit 1
    fi
    
    print_success "✅ MFA authentication successful!"
    print_status "Session expires at: $EXPIRATION"
    echo "" >&2
}

# Function to output credentials for sourcing
output_credentials() {
    print_status "Outputting credentials for sourcing..." >&2
    
    # Output the export commands to stdout (not stderr)
    echo "export AWS_ACCESS_KEY_ID='$ACCESS_KEY'"
    echo "export AWS_SECRET_ACCESS_KEY='$SECRET_KEY'"
    echo "export AWS_SESSION_TOKEN='$SESSION_TOKEN'"
    
    print_success "✅ Credentials ready!" >&2
    print_warning "These credentials expire in $(($SESSION_DURATION / 60)) minutes." >&2
    echo "" >&2
}

# Function to save credentials to file
save_credentials() {
    CREDS_FILE="aws-mfa-credentials.env"
    
    cat > "$CREDS_FILE" << EOF
# AWS MFA Temporary Credentials
# Generated: $(date)
# Expires: $EXPIRATION

export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
export AWS_SESSION_TOKEN="$SESSION_TOKEN"
EOF
    
    print_success "Credentials saved to: $CREDS_FILE" >&2
    print_status "To use in another terminal: source $CREDS_FILE" >&2
    print_warning "🔒 This file contains sensitive credentials and is excluded by .gitignore" >&2
    echo "" >&2
}

# Function to test credentials (only if already set)
test_credentials() {
    if [ -z "$AWS_SESSION_TOKEN" ]; then
        print_error "No MFA session found. Please source the credentials first."
        exit 1
    fi
    
    print_status "Testing credentials..."
    
    IDENTITY=$(aws sts get-caller-identity --output json 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        USER_ARN=$(echo "$IDENTITY" | jq -r '.Arn')
        ACCOUNT_ID=$(echo "$IDENTITY" | jq -r '.Account')
        
        print_success "✅ Credentials are working!"
        print_status "Identity: $USER_ARN"
        print_status "Account: $ACCOUNT_ID"
        
        # Check if it's a session (temporary) credential
        if [[ $USER_ARN == *"assumed-role"* ]] || [[ $USER_ARN == *"federated-user"* ]]; then
            print_success "✅ Using temporary (MFA) credentials"
        else
            print_warning "⚠️  Still using permanent credentials - MFA may not be active"
        fi
    else
        print_error "❌ Credentials test failed!"
        exit 1
    fi
    echo ""
}

# Function to show usage instructions
show_usage() {
    print_success "🚀 Ready for AWS operations!" >&2
    echo "" >&2
    echo "Usage:" >&2
    echo "  eval \$(./mfa-auth.sh)           # Set credentials in current shell" >&2
    echo "  source <(./mfa-auth.sh)         # Alternative sourcing method" >&2
    echo "  source aws-mfa-credentials.env  # Use saved credentials file" >&2
    echo "" >&2
    echo "After sourcing, you can run:" >&2
    echo "  aws s3 ls                       # Should work with MFA" >&2
    echo "  aws sts get-caller-identity     # Check current identity" >&2
    echo "  terraform init/plan/apply       # Run Terraform commands" >&2
    echo "" >&2
    print_warning "Remember: These credentials expire in $(($SESSION_DURATION / 60)) minutes!" >&2
}

# Main function
main() {
    echo "" >&2
    echo "🔐 AWS MFA Authentication Script" >&2
    echo "================================" >&2
    
    # Clear any expired credentials first
    clear_expired_credentials
    
    # Check prerequisites
    check_aws_cli
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install it first:"
        echo "  Ubuntu/Debian: sudo apt-get install jq" >&2
        echo "  macOS: brew install jq" >&2
        echo "  Windows (WSL): sudo apt-get install jq" >&2
        exit 1
    fi
    
    # Get MFA token and credentials
    get_mfa_token
    
    # Output credentials for sourcing
    output_credentials
    
    # Save credentials to file
    save_credentials
    
    # Show usage instructions
    show_usage
}

# Handle script arguments
case "${1:-}" in
    "test")
        test_credentials
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [command]" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  (no args)  Get MFA credentials and output for sourcing" >&2
        echo "  test       Test current MFA credentials" >&2
        echo "  help       Show this help message" >&2
        echo "" >&2
        echo "Examples:" >&2
        echo "  eval \$(./mfa-auth.sh)           # Set credentials in current shell" >&2
        echo "  source <(./mfa-auth.sh)         # Alternative method" >&2
        echo "  ./mfa-auth.sh test              # Test current credentials" >&2
        echo "" >&2
        echo "Configuration:" >&2
        echo "  MFA Serial: $MFA_SERIAL_NUMBER" >&2
        echo "  Session Duration: $(($SESSION_DURATION / 60)) minutes" >&2
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Run '$0 help' for usage information." >&2
        exit 1
        ;;
esac 