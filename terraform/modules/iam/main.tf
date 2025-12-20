# DMS VPC Management Role
resource "aws_iam_role" "dms_vpc_role" {
  name = "dms-vpc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-dms-vpc-role"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

resource "aws_iam_role_policy_attachment" "dms_vpc_role" {
  role       = aws_iam_role.dms_vpc_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

# DMS CloudWatch Logs Role
resource "aws_iam_role" "dms_cloudwatch_logs_role" {
  name = "dms-cloudwatch-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-dms-cloudwatch-role"
      Environment = var.environment
    }
  )
}

resource "aws_iam_role_policy_attachment" "dms_cloudwatch_logs_role" {
  role       = aws_iam_role.dms_cloudwatch_logs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
}

# DMS Redshift S3 Role
resource "aws_iam_role" "dms_redshift_s3_role" {
  name = "${var.project_name}-${var.environment}-dms-redshift-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "redshift.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-dms-redshift-s3-role"
      Environment = var.environment
    }
  )
}

resource "aws_iam_role_policy" "dms_s3_policy" {
  name = "${var.project_name}-${var.environment}-dms-s3-policy"
  role = aws_iam_role.dms_redshift_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = var.s3_bucket_arn != "" ? [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ] : ["*"]
      }
    ]
  })
}

# Cross-Account Role for Source Account
resource "aws_iam_role" "cross_account_source" {
  name = "${var.project_name}-${var.environment}-cross-account-source-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.target_account_id}:root"
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "${var.project_name}-${var.environment}"
          }
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-cross-account-source"
      Environment = var.environment
    }
  )
}

resource "aws_iam_role_policy" "cross_account_source_policy" {
  name = "${var.project_name}-${var.environment}-cross-account-source-policy"
  role = aws_iam_role.cross_account_source.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
      }
    ]
  })
}

# Cross-Account Role for Target Account
resource "aws_iam_role" "cross_account_target" {
  name = "${var.project_name}-${var.environment}-cross-account-target-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-cross-account-target"
      Environment = var.environment
    }
  )
}

resource "aws_iam_role_policy" "cross_account_target_policy" {
  name = "${var.project_name}-${var.environment}-cross-account-target-policy"
  role = aws_iam_role.cross_account_target.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = "arn:aws:iam::${var.source_account_id}:role/${aws_iam_role.cross_account_source.name}"
      }
    ]
  })
}
