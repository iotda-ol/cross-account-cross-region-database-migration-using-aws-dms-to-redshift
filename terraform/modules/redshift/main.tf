# Redshift Subnet Group
resource "aws_redshift_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-redshift-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-redshift-subnet-group"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# Security Group for Redshift
resource "aws_security_group" "redshift" {
  name        = "${var.project_name}-${var.environment}-redshift-sg"
  description = "Security group for Redshift cluster"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-redshift-sg"
      Environment = var.environment
    }
  )
}

# Ingress rule for Redshift
resource "aws_vpc_security_group_ingress_rule" "redshift" {
  security_group_id = aws_security_group.redshift.id
  description       = "Allow Redshift traffic"
  ip_protocol       = "tcp"
  from_port         = 5439
  to_port           = 5439
  cidr_ipv4         = "10.0.0.0/8"
}

# Egress rule - allow all outbound
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.redshift.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Parameter Group for Redshift
resource "aws_redshift_parameter_group" "main" {
  name   = "${var.project_name}-${var.environment}-redshift-params"
  family = "redshift-1.0"

  parameter {
    name  = "enable_user_activity_logging"
    value = "true"
  }

  parameter {
    name  = "require_ssl"
    value = "true"
  }

  parameter {
    name  = "use_fips_ssl"
    value = "false"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-redshift-params"
      Environment = var.environment
    }
  )
}

# Redshift Cluster
resource "aws_redshift_cluster" "main" {
  cluster_identifier  = var.cluster_identifier
  database_name       = var.database_name
  master_username     = var.master_username
  master_password     = var.master_password
  node_type           = var.node_type
  number_of_nodes     = var.number_of_nodes
  cluster_type        = var.number_of_nodes > 1 ? "multi-node" : "single-node"

  cluster_subnet_group_name    = aws_redshift_subnet_group.main.name
  vpc_security_group_ids       = [aws_security_group.redshift.id]
  cluster_parameter_group_name = aws_redshift_parameter_group.main.name

  publicly_accessible = var.publicly_accessible
  encrypted           = var.encrypted
  kms_key_id          = var.kms_key_id != "" ? var.kms_key_id : null

  preferred_maintenance_window        = var.preferred_maintenance_window
  automated_snapshot_retention_period = var.automated_snapshot_retention_period
  skip_final_snapshot                 = var.skip_final_snapshot
  final_snapshot_identifier           = var.skip_final_snapshot ? null : "${var.cluster_identifier}-final-snapshot"

  enhanced_vpc_routing = true

  logging {
    enable        = var.enable_logging
    bucket_name   = var.logging_bucket_name != "" ? var.logging_bucket_name : null
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-redshift"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}
