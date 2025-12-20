output "sns_topic_arn" {
  description = "ARN of the SNS topic for alarms"
  value       = var.alarm_email != "" ? aws_sns_topic.dms_alarms[0].arn : null
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.dms_tasks.name
}
