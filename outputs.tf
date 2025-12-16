# Network Outputs
output "vpc_id" {
  description = "ID of the target VPC"
  value       = aws_vpc.target.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.target_private[*].id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.target_public[*].id
}

# DMS Outputs
output "dms_replication_instance_arn" {
  description = "ARN of the DMS replication instance"
  value       = aws_dms_replication_instance.main.replication_instance_arn
}

output "dms_replication_instance_id" {
  description = "ID of the DMS replication instance"
  value       = aws_dms_replication_instance.main.replication_instance_id
}

output "dms_replication_instance_private_ips" {
  description = "Private IP addresses of the DMS replication instance"
  value       = aws_dms_replication_instance.main.replication_instance_private_ips
}

output "dms_source_endpoint_arn" {
  description = "ARN of the source DMS endpoint"
  value       = aws_dms_endpoint.source.endpoint_arn
}

output "dms_target_endpoint_arn" {
  description = "ARN of the target DMS endpoint"
  value       = aws_dms_endpoint.target.endpoint_arn
}

output "dms_replication_task_arn" {
  description = "ARN of the DMS replication task"
  value       = aws_dms_replication_task.main.replication_task_arn
}

# Redshift Outputs
output "redshift_cluster_id" {
  description = "ID of the Redshift cluster"
  value       = aws_redshift_cluster.main.id
}

output "redshift_cluster_endpoint" {
  description = "Endpoint of the Redshift cluster"
  value       = aws_redshift_cluster.main.endpoint
  sensitive   = true
}

output "redshift_cluster_hostname" {
  description = "Hostname of the Redshift cluster"
  value       = split(":", aws_redshift_cluster.main.endpoint)[0]
}

output "redshift_cluster_port" {
  description = "Port of the Redshift cluster"
  value       = aws_redshift_cluster.main.port
}

output "redshift_database_name" {
  description = "Name of the Redshift database"
  value       = aws_redshift_cluster.main.database_name
}

# S3 Outputs
output "dms_intermediate_s3_bucket" {
  description = "Name of the S3 bucket for DMS intermediate storage"
  value       = aws_s3_bucket.dms_intermediate.id
}

output "redshift_logs_s3_bucket" {
  description = "Name of the S3 bucket for Redshift logs"
  value       = aws_s3_bucket.redshift_logs.id
}

# IAM Outputs
output "dms_vpc_role_arn" {
  description = "ARN of the DMS VPC role"
  value       = aws_iam_role.dms_vpc_role.arn
}

output "dms_cloudwatch_logs_role_arn" {
  description = "ARN of the DMS CloudWatch logs role"
  value       = aws_iam_role.dms_cloudwatch_logs_role.arn
}

output "dms_redshift_s3_role_arn" {
  description = "ARN of the DMS Redshift S3 role"
  value       = aws_iam_role.dms_redshift_s3_role.arn
}

output "redshift_s3_role_arn" {
  description = "ARN of the Redshift S3 role"
  value       = aws_iam_role.redshift_s3_role.arn
}

# Security Group Outputs
output "dms_security_group_id" {
  description = "ID of the DMS security group"
  value       = aws_security_group.dms.id
}

output "redshift_security_group_id" {
  description = "ID of the Redshift security group"
  value       = aws_security_group.redshift.id
}

# KMS Outputs
output "dms_kms_key_id" {
  description = "ID of the KMS key for DMS"
  value       = aws_kms_key.dms.id
}

output "redshift_kms_key_id" {
  description = "ID of the KMS key for Redshift"
  value       = aws_kms_key.redshift.id
}

# CloudWatch Outputs
output "dms_cloudwatch_log_group" {
  description = "Name of the CloudWatch log group for DMS"
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.dms[0].name : null
}

# Connection Information
output "connection_instructions" {
  description = "Instructions for connecting to the Redshift cluster"
  sensitive   = true
  value       = <<-EOT
    To connect to the Redshift cluster:
    
    1. Ensure you are in the same VPC or have VPC peering/VPN configured
    2. Use the following connection details:
       Host: ${split(":", aws_redshift_cluster.main.endpoint)[0]}
       Port: ${aws_redshift_cluster.main.port}
       Database: ${aws_redshift_cluster.main.database_name}
       Username: ${var.redshift_master_username}
    
    3. To start the DMS replication task:
       aws dms start-replication-task \
         --replication-task-arn ${aws_dms_replication_task.main.replication_task_arn} \
         --start-replication-task-type start-replication
    
    4. Monitor the task status:
       aws dms describe-replication-tasks \
         --filters Name=replication-task-arn,Values=${aws_dms_replication_task.main.replication_task_arn}
  EOT
}
