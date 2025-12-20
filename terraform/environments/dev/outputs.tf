output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.db_instance_endpoint
  sensitive   = true
}

output "redshift_endpoint" {
  description = "Redshift endpoint"
  value       = module.redshift.cluster_endpoint
  sensitive   = true
}

output "dms_replication_instance_arn" {
  description = "DMS replication instance ARN"
  value       = module.dms.replication_instance_arn
}

output "s3_bucket_name" {
  description = "S3 bucket name for DMS"
  value       = module.s3.bucket_id
}
