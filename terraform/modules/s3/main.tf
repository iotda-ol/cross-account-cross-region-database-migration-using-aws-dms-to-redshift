# S3 Bucket for DMS
resource "aws_s3_bucket" "dms" {
  bucket = "${var.project_name}-${var.environment}-dms-bucket"

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-dms-bucket"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# Bucket Versioning
resource "aws_s3_bucket_versioning" "dms" {
  count  = var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.dms.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "dms" {
  count  = var.enable_encryption ? 1 : 0
  bucket = aws_s3_bucket.dms.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "dms" {
  bucket = aws_s3_bucket.dms.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "dms" {
  count  = var.lifecycle_rules_enabled ? 1 : 0
  bucket = aws_s3_bucket.dms.id

  rule {
    id     = "delete-old-objects"
    status = "Enabled"

    expiration {
      days = var.expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }
  }
}

# Bucket Policy for DMS
resource "aws_s3_bucket_policy" "dms" {
  bucket = aws_s3_bucket.dms.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.dms.arn,
          "${aws_s3_bucket.dms.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
