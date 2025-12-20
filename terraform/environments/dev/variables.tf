# Variables for dev environment

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "source_account_id" {
  description = "AWS account ID of the source account"
  type        = string
}

variable "target_account_id" {
  description = "AWS account ID of the target account"
  type        = string
}

variable "source_region" {
  description = "AWS region for source resources"
  type        = string
}

variable "target_region" {
  description = "AWS region for target resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets"
  type        = list(string)
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
}

variable "rds_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
}

variable "rds_db_name" {
  description = "RDS database name"
  type        = string
}

variable "rds_username" {
  description = "RDS master username"
  type        = string
  sensitive   = true
}

variable "rds_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = false
}

variable "redshift_node_type" {
  description = "Redshift node type"
  type        = string
}

variable "redshift_number_of_nodes" {
  description = "Number of Redshift nodes"
  type        = number
}

variable "redshift_database_name" {
  description = "Redshift database name"
  type        = string
}

variable "redshift_master_username" {
  description = "Redshift master username"
  type        = string
  sensitive   = true
}

variable "redshift_master_password" {
  description = "Redshift master password"
  type        = string
  sensitive   = true
}

variable "dms_instance_class" {
  description = "DMS instance class"
  type        = string
}

variable "dms_allocated_storage" {
  description = "DMS allocated storage in GB"
  type        = number
}

variable "dms_engine_version" {
  description = "DMS engine version"
  type        = string
}

variable "dms_replication_instance_id" {
  description = "DMS replication instance ID"
  type        = string
}

variable "dms_multi_az" {
  description = "Enable Multi-AZ for DMS"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
