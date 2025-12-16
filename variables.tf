variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "dms-migration"
}

# Region Configuration
variable "target_region" {
  description = "Target AWS region where DMS and Redshift are deployed"
  type        = string
  default     = "eu-west-1"
}

variable "source_region" {
  description = "Source AWS region where RDS PostgreSQL is located"
  type        = string
  default     = "us-east-1"
}

# Cross-Account Configuration
variable "source_account_id" {
  description = "Source AWS account ID where RDS PostgreSQL is located"
  type        = string
}

variable "source_account_role_arn" {
  description = "IAM role ARN in source account for cross-account access"
  type        = string
}

# Network Configuration
variable "target_vpc_cidr" {
  description = "CIDR block for target VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "target_private_subnet_cidrs" {
  description = "CIDR blocks for target private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "target_public_subnet_cidrs" {
  description = "CIDR blocks for target public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "availability_zones" {
  description = "Availability zones for the target region"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

# Source RDS Configuration
variable "source_rds_endpoint" {
  description = "Endpoint of the source RDS PostgreSQL instance"
  type        = string
}

variable "source_rds_port" {
  description = "Port of the source RDS PostgreSQL instance"
  type        = number
  default     = 5432
}

variable "source_rds_database_name" {
  description = "Database name in source RDS PostgreSQL"
  type        = string
}

variable "source_rds_username" {
  description = "Username for source RDS PostgreSQL"
  type        = string
  sensitive   = true
}

variable "source_rds_password" {
  description = "Password for source RDS PostgreSQL"
  type        = string
  sensitive   = true
}

# Redshift Configuration
variable "redshift_cluster_identifier" {
  description = "Identifier for the Redshift cluster"
  type        = string
  default     = "dms-target-redshift"
}

variable "redshift_database_name" {
  description = "Database name in Redshift cluster"
  type        = string
  default     = "targetdb"
}

variable "redshift_master_username" {
  description = "Master username for Redshift cluster"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "redshift_master_password" {
  description = "Master password for Redshift cluster"
  type        = string
  sensitive   = true
}

variable "redshift_node_type" {
  description = "Node type for Redshift cluster"
  type        = string
  default     = "dc2.large"
}

variable "redshift_number_of_nodes" {
  description = "Number of nodes in Redshift cluster"
  type        = number
  default     = 2
}

# DMS Configuration
variable "dms_replication_instance_class" {
  description = "Instance class for DMS replication instance"
  type        = string
  default     = "dms.t3.medium"
}

variable "dms_replication_instance_id" {
  description = "Identifier for DMS replication instance"
  type        = string
  default     = "dms-replication-instance"
}

variable "dms_allocated_storage" {
  description = "Allocated storage in GB for DMS replication instance"
  type        = number
  default     = 100
}

variable "dms_engine_version" {
  description = "DMS engine version"
  type        = string
  default     = "3.5.2"
}

variable "dms_multi_az" {
  description = "Enable Multi-AZ for DMS replication instance"
  type        = bool
  default     = false
}

variable "dms_publicly_accessible" {
  description = "Make DMS replication instance publicly accessible"
  type        = bool
  default     = false
}

# Migration Configuration
variable "migration_type" {
  description = "Migration type: full-load, cdc, or full-load-and-cdc"
  type        = string
  default     = "full-load-and-cdc"

  validation {
    condition     = contains(["full-load", "cdc", "full-load-and-cdc"], var.migration_type)
    error_message = "Migration type must be one of: full-load, cdc, full-load-and-cdc"
  }
}

variable "table_mappings_file" {
  description = "Path to table mappings JSON file"
  type        = string
  default     = "table-mappings.json"
}

# Security Configuration
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the DMS instance"
  type        = list(string)
  default     = []
}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logs for DMS"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
