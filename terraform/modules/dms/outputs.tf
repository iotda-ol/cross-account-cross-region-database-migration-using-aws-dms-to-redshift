output "replication_instance_id" {
  description = "ID of the DMS replication instance"
  value       = aws_dms_replication_instance.main.replication_instance_id
}

output "replication_instance_arn" {
  description = "ARN of the DMS replication instance"
  value       = aws_dms_replication_instance.main.replication_instance_arn
}

output "replication_instance_private_ips" {
  description = "Private IP addresses of the DMS replication instance"
  value       = aws_dms_replication_instance.main.replication_instance_private_ips
}

output "replication_instance_public_ips" {
  description = "Public IP addresses of the DMS replication instance"
  value       = aws_dms_replication_instance.main.replication_instance_public_ips
}

output "security_group_id" {
  description = "ID of the DMS security group"
  value       = aws_security_group.dms.id
}

output "subnet_group_id" {
  description = "ID of the DMS subnet group"
  value       = aws_dms_replication_subnet_group.main.id
}
