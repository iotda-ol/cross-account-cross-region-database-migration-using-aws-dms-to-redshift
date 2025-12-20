# DMS Subnet Group
resource "aws_dms_replication_subnet_group" "main" {
  replication_subnet_group_id          = "${var.project_name}-${var.environment}-dms-subnet-group"
  replication_subnet_group_description = "DMS replication subnet group for ${var.project_name}"
  subnet_ids                           = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-dms-subnet-group"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# Security Group for DMS
resource "aws_security_group" "dms" {
  name        = "${var.project_name}-${var.environment}-dms-sg"
  description = "Security group for DMS replication instance"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-dms-sg"
      Environment = var.environment
    }
  )
}

# Ingress rule for PostgreSQL (from source)
resource "aws_vpc_security_group_ingress_rule" "postgres" {
  security_group_id = aws_security_group.dms.id
  description       = "Allow PostgreSQL traffic"
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
  cidr_ipv4         = "0.0.0.0/0"
}

# Ingress rule for Redshift (to target)
resource "aws_vpc_security_group_ingress_rule" "redshift" {
  security_group_id = aws_security_group.dms.id
  description       = "Allow Redshift traffic"
  ip_protocol       = "tcp"
  from_port         = 5439
  to_port           = 5439
  cidr_ipv4         = "0.0.0.0/0"
}

# Egress rule - allow all outbound
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.dms.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# DMS Replication Instance
resource "aws_dms_replication_instance" "main" {
  replication_instance_id      = var.replication_instance_id
  replication_instance_class   = var.replication_instance_class
  allocated_storage            = var.allocated_storage
  engine_version               = var.engine_version
  multi_az                     = var.multi_az
  publicly_accessible          = var.publicly_accessible
  auto_minor_version_upgrade   = var.auto_minor_version_upgrade
  preferred_maintenance_window = var.preferred_maintenance_window
  replication_subnet_group_id  = aws_dms_replication_subnet_group.main.id
  vpc_security_group_ids       = [aws_security_group.dms.id]
  kms_key_arn                  = var.kms_key_arn != "" ? var.kms_key_arn : null

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-dms-instance"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )

  depends_on = [
    aws_dms_replication_subnet_group.main
  ]
}

# CloudWatch Log Group for DMS
resource "aws_cloudwatch_log_group" "dms" {
  name              = "/aws/dms/${var.replication_instance_id}"
  retention_in_days = 30

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-dms-logs"
      Environment = var.environment
    }
  )
}
