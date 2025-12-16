# Redshift Cluster
resource "aws_redshift_cluster" "main" {
  cluster_identifier = var.redshift_cluster_identifier
  database_name      = var.redshift_database_name
  master_username    = var.redshift_master_username
  master_password    = var.redshift_master_password
  node_type          = var.redshift_node_type
  cluster_type       = var.redshift_number_of_nodes > 1 ? "multi-node" : "single-node"
  number_of_nodes    = var.redshift_number_of_nodes > 1 ? var.redshift_number_of_nodes : null

  # Network configuration
  cluster_subnet_group_name = aws_redshift_subnet_group.redshift.name
  vpc_security_group_ids    = [aws_security_group.redshift.id]
  publicly_accessible       = false
  enhanced_vpc_routing      = true

  # IAM role for COPY/UNLOAD
  iam_roles = [aws_iam_role.redshift_s3_role.arn]

  # Encryption
  encrypted  = true
  kms_key_id = aws_kms_key.redshift.arn

  # Backup and maintenance
  automated_snapshot_retention_period = 7
  preferred_maintenance_window        = "sun:05:00-sun:06:00"
  skip_final_snapshot                 = true

  # Logging
  logging {
    enable        = true
    bucket_name   = aws_s3_bucket.redshift_logs.id
    s3_key_prefix = "redshift-logs/"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-redshift-cluster"
    }
  )

  depends_on = [
    aws_redshift_subnet_group.redshift,
    aws_iam_role.redshift_s3_role
  ]
}

# KMS Key for Redshift encryption
resource "aws_kms_key" "redshift" {
  description             = "KMS key for Redshift cluster encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-redshift-kms-key"
    }
  )
}

resource "aws_kms_alias" "redshift" {
  name          = "alias/${var.project_name}-${var.environment}-redshift"
  target_key_id = aws_kms_key.redshift.key_id
}

# KMS Key Policy for Redshift
resource "aws_kms_key_policy" "redshift" {
  key_id = aws_kms_key.redshift.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Redshift to use the key"
        Effect = "Allow"
        Principal = {
          Service = "redshift.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "redshift.${var.target_region}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "Allow S3 to use the key for logs"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${var.target_region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

# S3 Bucket for Redshift Logs
resource "aws_s3_bucket" "redshift_logs" {
  bucket = "${var.project_name}-${var.environment}-redshift-logs-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-redshift-logs"
    }
  )
}

# Enable versioning for Redshift logs bucket
resource "aws_s3_bucket_versioning" "redshift_logs" {
  bucket = aws_s3_bucket.redshift_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption for Redshift logs bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "redshift_logs" {
  bucket = aws_s3_bucket.redshift_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.redshift.arn
    }
  }
}

# Block public access to Redshift logs bucket
resource "aws_s3_bucket_public_access_block" "redshift_logs" {
  bucket = aws_s3_bucket.redshift_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy for Redshift logs
resource "aws_s3_bucket_lifecycle_configuration" "redshift_logs" {
  bucket = aws_s3_bucket.redshift_logs.id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }
  }
}

# Redshift logs bucket policy
resource "aws_s3_bucket_policy" "redshift_logs" {
  bucket = aws_s3_bucket.redshift_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Put bucket policy needed for Redshift audit logging"
        Effect = "Allow"
        Principal = {
          Service = "redshift.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.redshift_logs.arn}/*"
      },
      {
        Sid    = "Get bucket policy needed for Redshift audit logging"
        Effect = "Allow"
        Principal = {
          Service = "redshift.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.redshift_logs.arn
      }
    ]
  })
}

# CloudWatch Alarms for Redshift Monitoring
resource "aws_cloudwatch_metric_alarm" "redshift_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-redshift-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/Redshift"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors Redshift cluster CPU utilization"

  dimensions = {
    ClusterIdentifier = aws_redshift_cluster.main.cluster_identifier
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "redshift_disk" {
  alarm_name          = "${var.project_name}-${var.environment}-redshift-disk-space"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "PercentageDiskSpaceUsed"
  namespace           = "AWS/Redshift"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "This metric monitors Redshift cluster disk space usage"

  dimensions = {
    ClusterIdentifier = aws_redshift_cluster.main.cluster_identifier
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "redshift_health" {
  alarm_name          = "${var.project_name}-${var.environment}-redshift-health-status"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthStatus"
  namespace           = "AWS/Redshift"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "This metric monitors Redshift cluster health status"

  dimensions = {
    ClusterIdentifier = aws_redshift_cluster.main.cluster_identifier
  }

  tags = var.tags
}
