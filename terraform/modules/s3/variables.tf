# S3 Module for DMS
# Reusable module for creating S3 buckets for DMS tasks

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "enable_versioning" {
  description = "Enable bucket versioning"
  type        = bool
  default     = true
}

variable "enable_encryption" {
  description = "Enable server-side encryption"
  type        = bool
  default     = true
}

variable "lifecycle_rules_enabled" {
  description = "Enable lifecycle rules"
  type        = bool
  default     = true
}

variable "expiration_days" {
  description = "Days until objects expire"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
