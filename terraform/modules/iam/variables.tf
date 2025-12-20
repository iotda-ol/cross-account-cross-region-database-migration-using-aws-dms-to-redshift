# IAM Module for DMS Cross-Account Access
# Reusable module for creating IAM roles and policies

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "source_account_id" {
  description = "AWS account ID of the source account"
  type        = string
}

variable "target_account_id" {
  description = "AWS account ID of the target account"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of S3 bucket for DMS"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
