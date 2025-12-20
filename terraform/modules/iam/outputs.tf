output "dms_vpc_role_arn" {
  description = "ARN of the DMS VPC management role"
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

output "cross_account_source_role_arn" {
  description = "ARN of the cross-account source role"
  value       = aws_iam_role.cross_account_source.arn
}

output "cross_account_target_role_arn" {
  description = "ARN of the cross-account target role"
  value       = aws_iam_role.cross_account_target.arn
}
