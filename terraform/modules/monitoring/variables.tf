# Monitoring Module for DMS
# CloudWatch alarms and dashboards

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "dms_task_arns" {
  description = "List of DMS task ARNs to monitor"
  type        = list(string)
  default     = []
}

variable "alarm_email" {
  description = "Email address for alarm notifications"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
