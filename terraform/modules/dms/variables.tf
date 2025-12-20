# AWS DMS Replication Instance Module
# Reusable module for creating DMS replication instances

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "replication_instance_class" {
  description = "Instance class for DMS replication instance"
  type        = string
  default     = "dms.t3.medium"
}

variable "replication_instance_id" {
  description = "Identifier for the replication instance"
  type        = string
}

variable "allocated_storage" {
  description = "Storage allocated to replication instance (GB)"
  type        = number
  default     = 100
}

variable "vpc_id" {
  description = "VPC ID where DMS instance will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for DMS replication subnet group"
  type        = list(string)
}

variable "multi_az" {
  description = "Enable multi-AZ for replication instance"
  type        = bool
  default     = false
}

variable "publicly_accessible" {
  description = "Make replication instance publicly accessible"
  type        = bool
  default     = false
}

variable "engine_version" {
  description = "DMS engine version"
  type        = string
  default     = "3.4.7"
}

variable "auto_minor_version_upgrade" {
  description = "Enable auto minor version upgrades"
  type        = bool
  default     = true
}

variable "preferred_maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "sun:05:00-sun:06:00"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access DMS instance"
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
