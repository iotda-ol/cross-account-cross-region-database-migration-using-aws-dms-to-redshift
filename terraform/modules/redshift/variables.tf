# Redshift Cluster Module (Target Database)
# Reusable module for creating Redshift clusters

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "cluster_identifier" {
  description = "Identifier for the Redshift cluster"
  type        = string
}

variable "database_name" {
  description = "Name of the database"
  type        = string
}

variable "master_username" {
  description = "Master username for the cluster"
  type        = string
  sensitive   = true
}

variable "master_password" {
  description = "Master password for the cluster"
  type        = string
  sensitive   = true
}

variable "node_type" {
  description = "Node type for Redshift cluster"
  type        = string
  default     = "dc2.large"
}

variable "number_of_nodes" {
  description = "Number of nodes in the cluster"
  type        = number
  default     = 2
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for Redshift subnet group"
  type        = list(string)
}

variable "publicly_accessible" {
  description = "Make cluster publicly accessible"
  type        = bool
  default     = false
}

variable "encrypted" {
  description = "Enable encryption at rest"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = ""
}

variable "preferred_maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "sun:05:00-sun:06:00"
}

variable "automated_snapshot_retention_period" {
  description = "Retention period for automated snapshots"
  type        = number
  default     = 7
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on cluster deletion"
  type        = bool
  default     = true
}

variable "enable_logging" {
  description = "Enable audit logging to S3"
  type        = bool
  default     = true
}

variable "logging_bucket_name" {
  description = "S3 bucket name for logging"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
