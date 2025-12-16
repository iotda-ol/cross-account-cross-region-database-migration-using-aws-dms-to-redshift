# DMS Replication Instance
resource "aws_dms_replication_instance" "main" {
  replication_instance_id    = var.dms_replication_instance_id
  replication_instance_class = var.dms_replication_instance_class
  allocated_storage          = var.dms_allocated_storage
  engine_version             = var.dms_engine_version
  multi_az                   = var.dms_multi_az
  publicly_accessible        = var.dms_publicly_accessible

  replication_subnet_group_id = aws_dms_replication_subnet_group.dms.id
  vpc_security_group_ids      = [aws_security_group.dms.id]

  kms_key_arn = aws_kms_key.dms.arn

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-dms-replication-instance"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.dms_vpc_role,
    aws_iam_role_policy_attachment.dms_cloudwatch_logs_role
  ]
}

# DMS Source Endpoint (RDS PostgreSQL in source account)
resource "aws_dms_endpoint" "source" {
  endpoint_id   = "${var.project_name}-${var.environment}-source-rds"
  endpoint_type = "source"
  engine_name   = "postgres"

  server_name   = var.source_rds_endpoint
  port          = var.source_rds_port
  database_name = var.source_rds_database_name
  username      = var.source_rds_username
  password      = var.source_rds_password

  ssl_mode = "require"

  # PostgreSQL specific settings
  postgres_settings {
    # Enable continuous replication for CDC
    capture_ddls  = true
    max_file_size = 512000

    # Slot name for logical replication
    slot_name = "${replace(var.project_name, "-", "_")}_${var.environment}_slot"

    # Plugin for logical replication
    plugin_name = "pglogical"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-source-endpoint"
    }
  )
}

# DMS Target Endpoint (Redshift in target account)
resource "aws_dms_endpoint" "target" {
  endpoint_id   = "${var.project_name}-${var.environment}-target-redshift"
  endpoint_type = "target"
  engine_name   = "redshift"

  server_name   = aws_redshift_cluster.main.endpoint
  port          = 5439
  database_name = var.redshift_database_name
  username      = var.redshift_master_username
  password      = var.redshift_master_password

  ssl_mode = "require"

  # Redshift specific settings
  redshift_settings {
    bucket_name             = aws_s3_bucket.dms_intermediate.id
    bucket_folder           = "dms-data"
    service_access_role_arn = aws_iam_role.dms_redshift_s3_role.arn
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-target-endpoint"
    }
  )

  depends_on = [
    aws_redshift_cluster.main,
    aws_s3_bucket.dms_intermediate
  ]
}

# DMS Replication Task
resource "aws_dms_replication_task" "main" {
  replication_task_id      = "${var.project_name}-${var.environment}-replication-task"
  migration_type           = var.migration_type
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target.endpoint_arn

  # Table mappings define which tables to replicate
  table_mappings = jsonencode({
    rules = [
      {
        rule-type = "selection"
        rule-id   = "1"
        rule-name = "replicate-all-tables"
        object-locator = {
          schema-name = "public"
          table-name  = "%"
        }
        rule-action = "include"
      }
    ]
  })

  # Replication task settings
  replication_task_settings = jsonencode({
    Logging = {
      EnableLogging = var.enable_cloudwatch_logs
      LogComponents = [
        {
          Id       = "SOURCE_CAPTURE"
          Severity = "LOGGER_SEVERITY_INFO"
        },
        {
          Id       = "TARGET_APPLY"
          Severity = "LOGGER_SEVERITY_INFO"
        },
        {
          Id       = "TASK_MANAGER"
          Severity = "LOGGER_SEVERITY_INFO"
        }
      ]
    }
    ControlTablesSettings = {
      ControlSchema               = "dms_control"
      HistoryTimeslotInMinutes    = 5
      HistoryTableEnabled         = true
      SuspendedTablesTableEnabled = true
      StatusTableEnabled          = true
    }
    FullLoadSettings = {
      TargetTablePrepMode           = "DROP_AND_CREATE"
      MaxFullLoadSubTasks           = 8
      TransactionConsistencyTimeout = 600
      CommitRate                    = 10000
    }
    ChangeProcessingDdlHandlingPolicy = {
      HandleSourceTableDropped   = true
      HandleSourceTableTruncated = true
      HandleSourceTableAltered   = true
    }
    ErrorBehavior = {
      DataErrorPolicy               = "LOG_ERROR"
      EventErrorPolicy              = "IGNORE"
      DataTruncationErrorPolicy     = "LOG_ERROR"
      DataErrorEscalationPolicy     = "SUSPEND_TABLE"
      DataErrorEscalationCount      = 50
      TableErrorPolicy              = "SUSPEND_TABLE"
      TableErrorEscalationPolicy    = "STOP_TASK"
      TableErrorEscalationCount     = 50
      RecoverableErrorCount         = -1
      RecoverableErrorInterval      = 5
      RecoverableErrorThrottling    = true
      RecoverableErrorThrottlingMax = 1800
      ApplyErrorDeletePolicy        = "IGNORE_RECORD"
      ApplyErrorInsertPolicy        = "LOG_ERROR"
      ApplyErrorUpdatePolicy        = "LOG_ERROR"
      ApplyErrorEscalationPolicy    = "LOG_ERROR"
      ApplyErrorEscalationCount     = 0
      FullLoadIgnoreConflicts       = true
    }
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-replication-task"
    }
  )

  depends_on = [
    aws_dms_endpoint.source,
    aws_dms_endpoint.target
  ]
}

# CloudWatch Log Group for DMS
resource "aws_cloudwatch_log_group" "dms" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/dms/${var.project_name}-${var.environment}"
  retention_in_days = 7

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-dms-logs"
    }
  )
}

# CloudWatch Alarms for DMS Monitoring
resource "aws_cloudwatch_metric_alarm" "dms_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-dms-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/DMS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors DMS replication instance CPU utilization"

  dimensions = {
    ReplicationInstanceIdentifier = aws_dms_replication_instance.main.replication_instance_id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "dms_memory" {
  alarm_name          = "${var.project_name}-${var.environment}-dms-low-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/DMS"
  period              = 300
  statistic           = "Average"
  threshold           = 1073741824 # 1 GB in bytes
  alarm_description   = "This metric monitors DMS replication instance available memory"

  dimensions = {
    ReplicationInstanceIdentifier = aws_dms_replication_instance.main.replication_instance_id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "dms_storage" {
  alarm_name          = "${var.project_name}-${var.environment}-dms-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/DMS"
  period              = 300
  statistic           = "Average"
  threshold           = 10737418240 # 10 GB in bytes
  alarm_description   = "This metric monitors DMS replication instance available storage"

  dimensions = {
    ReplicationInstanceIdentifier = aws_dms_replication_instance.main.replication_instance_id
  }

  tags = var.tags
}
