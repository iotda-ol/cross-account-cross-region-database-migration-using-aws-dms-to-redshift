# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-db-subnet-group"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-rds-sg"
      Environment = var.environment
    }
  )
}

# Ingress rule for PostgreSQL
resource "aws_vpc_security_group_ingress_rule" "postgres" {
  security_group_id = aws_security_group.rds.id
  description       = "Allow PostgreSQL traffic from allowed CIDR blocks"
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
  cidr_ipv4         = "10.0.0.0/8"
}

# Egress rule - allow all outbound
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.rds.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Parameter Group for DMS
resource "aws_db_parameter_group" "main" {
  name   = "${var.project_name}-${var.environment}-postgres-params"
  family = "postgres15"

  # Enable logical replication for DMS
  parameter {
    name  = "rds.logical_replication"
    value = "1"
  }

  parameter {
    name  = "max_replication_slots"
    value = "10"
  }

  parameter {
    name  = "max_wal_senders"
    value = "10"
  }

  parameter {
    name  = "wal_sender_timeout"
    value = "0"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-postgres-params"
      Environment = var.environment
    }
  )
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-${var.environment}-postgres"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = var.kms_key_id != "" ? var.kms_key_id : null

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.main.name

  multi_az               = var.multi_az
  publicly_accessible    = false
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window

  enabled_cloudwatch_logs_exports = var.enable_cloudwatch_logs_exports

  skip_final_snapshot       = true
  final_snapshot_identifier = "${var.project_name}-${var.environment}-final-snapshot"

  copy_tags_to_snapshot = true
  deletion_protection   = false

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-postgres"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}
