output "cluster_id" {
  description = "ID of the Redshift cluster"
  value       = aws_redshift_cluster.main.id
}

output "cluster_arn" {
  description = "ARN of the Redshift cluster"
  value       = aws_redshift_cluster.main.arn
}

output "cluster_endpoint" {
  description = "Endpoint of the Redshift cluster"
  value       = aws_redshift_cluster.main.endpoint
}

output "cluster_dns_name" {
  description = "DNS name of the Redshift cluster"
  value       = aws_redshift_cluster.main.dns_name
}

output "cluster_port" {
  description = "Port of the Redshift cluster"
  value       = aws_redshift_cluster.main.port
}

output "database_name" {
  description = "Name of the database"
  value       = aws_redshift_cluster.main.database_name
}

output "security_group_id" {
  description = "ID of the Redshift security group"
  value       = aws_security_group.redshift.id
}
