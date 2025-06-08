# =============================================================================
# TERRAFORM CONFIGURATION
# =============================================================================
# This file defines the core Terraform configuration for the Energy Monitoring System
# It sets up the required providers, AWS configuration, and common data sources

terraform {
  required_version = ">= 1.0"
  
  # Define required providers with version constraints
  required_providers {
    # AWS provider for managing AWS resources
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # Use AWS provider version 5.x
    }
    # Archive provider for creating ZIP files for Lambda deployments
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"  # Use Archive provider version 2.4.x
    }
  }
}

# =============================================================================
# AWS PROVIDER CONFIGURATION
# =============================================================================
# Configure the AWS provider with region and default tags for all resources

provider "aws" {
  region = var.aws_region  # AWS region from variables (default: eu-central-1)
  
  # Apply default tags to all AWS resources created by this configuration
  # These tags help with resource management, cost tracking, and organization
  default_tags {
    tags = {
      Project     = "EnergyMonitoring"    # Project identifier
      Environment = var.environment       # Environment (dev/staging/prod)
      ManagedBy   = "Terraform"          # Indicates resource is managed by Terraform
    }
  }
}

# =============================================================================
# DATA SOURCES
# =============================================================================
# Data sources fetch information about existing AWS resources or account details

# Get current AWS account ID - used for constructing ARNs and policies
data "aws_caller_identity" "current" {}

# Get current AWS region - used for constructing ARNs and region-specific configurations
data "aws_region" "current" {} 