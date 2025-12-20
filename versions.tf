terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider for target account and region (eu-west-1)
provider "aws" {
  region = var.target_region

  default_tags {
    tags = {
      Project     = "DMS-Cross-Account-Migration"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Provider for source account (cross-account access)
provider "aws" {
  alias  = "source"
  region = var.source_region

  assume_role {
    role_arn = var.source_account_role_arn
  }

  default_tags {
    tags = {
      Project     = "DMS-Cross-Account-Migration"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
