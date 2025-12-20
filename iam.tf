# Data source to get current account ID
data "aws_caller_identity" "current" {}

# Data source to get partition
data "aws_partition" "current" {}

# DMS VPC Management Role
# This role allows DMS to manage VPC resources
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
      Name = "dms-vpc-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "dms_vpc_role" {
  role       = aws_iam_role.dms_vpc_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

# DMS CloudWatch Logs Role
# This role allows DMS to write logs to CloudWatch
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
      Name = "dms-cloudwatch-logs-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "dms_cloudwatch_logs_role" {
  role       = aws_iam_role.dms_cloudwatch_logs_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
}

# DMS Redshift S3 Access Role
# This role allows DMS to access S3 for Redshift data loading
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
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-dms-redshift-s3-role"
    }
  )
}

# S3 Bucket for DMS-Redshift intermediate storage
resource "aws_s3_bucket" "dms_intermediate" {
  bucket = "${var.project_name}-${var.environment}-dms-intermediate-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-dms-intermediate"
    }
  )
}

# Enable versioning for the S3 bucket
resource "aws_s3_bucket_versioning" "dms_intermediate" {
  bucket = aws_s3_bucket.dms_intermediate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption for the S3 bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "dms_intermediate" {
  bucket = aws_s3_bucket.dms_intermediate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access to the S3 bucket
resource "aws_s3_bucket_public_access_block" "dms_intermediate" {
  bucket = aws_s3_bucket.dms_intermediate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM policy for DMS to access S3 bucket
resource "aws_iam_role_policy" "dms_redshift_s3_policy" {
  name = "${var.project_name}-${var.environment}-dms-s3-access"
  role = aws_iam_role.dms_redshift_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.dms_intermediate.arn,
          "${aws_s3_bucket.dms_intermediate.arn}/*"
        ]
      }
    ]
  })
}

# Redshift IAM Role for COPY command
resource "aws_iam_role" "redshift_s3_role" {
  name = "${var.project_name}-${var.environment}-redshift-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
      Name = "${var.project_name}-${var.environment}-redshift-s3-role"
    }
  )
}

# IAM policy for Redshift to access S3 bucket
resource "aws_iam_role_policy" "redshift_s3_policy" {
  name = "${var.project_name}-${var.environment}-redshift-s3-access"
  role = aws_iam_role.redshift_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.dms_intermediate.arn,
          "${aws_s3_bucket.dms_intermediate.arn}/*"
        ]
      }
    ]
  })
}

# Cross-Account Role in Target Account for Source Account Access
# This role allows the source account to be accessed from the target account
# Note: Using account root is acceptable for initial setup. For production with known specific roles,
# replace the AWS principal with specific role ARNs and add ExternalId condition for additional security.
resource "aws_iam_role" "cross_account_dms" {
  name = "${var.project_name}-${var.environment}-cross-account-dms-role"

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
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        # Condition = {
        #   StringEquals = {
        #     "sts:ExternalId" = "unique-external-id-here"
        #   }
        # }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-cross-account-dms-role"
    }
  )
}

# Policy for cross-account DMS role
resource "aws_iam_role_policy" "cross_account_dms" {
  name = "${var.project_name}-${var.environment}-cross-account-dms-policy"
  role = aws_iam_role.cross_account_dms.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeNetworkInterfaces",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

# KMS Key for encrypting sensitive data
resource "aws_kms_key" "dms" {
  description             = "KMS key for DMS encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-dms-kms-key"
    }
  )
}

resource "aws_kms_alias" "dms" {
  name          = "alias/${var.project_name}-${var.environment}-dms"
  target_key_id = aws_kms_key.dms.key_id
}

# KMS Key Policy
resource "aws_kms_key_policy" "dms" {
  key_id = aws_kms_key.dms.id

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
        Sid    = "Allow DMS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
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
            "kms:ViaService" = "dms.${var.target_region}.amazonaws.com"
          }
        }
      }
    ]
  })
}
