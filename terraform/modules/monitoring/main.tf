# SNS Topic for Alarms
resource "aws_sns_topic" "dms_alarms" {
  count = var.alarm_email != "" ? 1 : 0
  name  = "${var.project_name}-${var.environment}-dms-alarms"

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-dms-alarms"
      Environment = var.environment
    }
  )
}

resource "aws_sns_topic_subscription" "dms_alarms_email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.dms_alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# CloudWatch Log Group for DMS
resource "aws_cloudwatch_log_group" "dms_tasks" {
  name              = "/aws/dms/${var.project_name}-${var.environment}"
  retention_in_days = 30

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-dms-logs"
      Environment = var.environment
    }
  )
}
