# VPC for Target Environment
resource "aws_vpc" "target" {
  cidr_block           = var.target_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-target-vpc"
    }
  )
}

# Internet Gateway for Target VPC
resource "aws_internet_gateway" "target" {
  vpc_id = aws_vpc.target.id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-target-igw"
    }
  )
}

# Private Subnets for DMS and Redshift
resource "aws_subnet" "target_private" {
  count             = length(var.target_private_subnet_cidrs)
  vpc_id            = aws_vpc.target.id
  cidr_block        = var.target_private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-target-private-${count.index + 1}"
      Type = "private"
    }
  )
}

# Public Subnets for NAT Gateways
resource "aws_subnet" "target_public" {
  count                   = length(var.target_public_subnet_cidrs)
  vpc_id                  = aws_vpc.target.id
  cidr_block              = var.target_public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-target-public-${count.index + 1}"
      Type = "public"
    }
  )
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = length(var.target_public_subnet_cidrs)
  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-nat-eip-${count.index + 1}"
    }
  )

  depends_on = [aws_internet_gateway.target]
}

# NAT Gateways for Private Subnet Internet Access
resource "aws_nat_gateway" "target" {
  count         = length(var.target_public_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.target_public[count.index].id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-nat-gw-${count.index + 1}"
    }
  )

  depends_on = [aws_internet_gateway.target]
}

# Route Table for Public Subnets
resource "aws_route_table" "target_public" {
  vpc_id = aws_vpc.target.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.target.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-target-public-rt"
    }
  )
}

# Route Table Associations for Public Subnets
resource "aws_route_table_association" "target_public" {
  count          = length(var.target_public_subnet_cidrs)
  subnet_id      = aws_subnet.target_public[count.index].id
  route_table_id = aws_route_table.target_public.id
}

# Route Tables for Private Subnets
resource "aws_route_table" "target_private" {
  count  = length(var.target_private_subnet_cidrs)
  vpc_id = aws_vpc.target.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.target[count.index].id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-target-private-rt-${count.index + 1}"
    }
  )
}

# Route Table Associations for Private Subnets
resource "aws_route_table_association" "target_private" {
  count          = length(var.target_private_subnet_cidrs)
  subnet_id      = aws_subnet.target_private[count.index].id
  route_table_id = aws_route_table.target_private[count.index].id
}

# Security Group for DMS Replication Instance
resource "aws_security_group" "dms" {
  name_prefix = "${var.project_name}-${var.environment}-dms-"
  description = "Security group for DMS replication instance"
  vpc_id      = aws_vpc.target.id

  # Egress to RDS PostgreSQL (source)
  # Note: 0.0.0.0/0 is used because source RDS is in a different AWS account and potentially different region.
  # For production, consider: VPC peering, PrivateLink, or replace with specific source VPC CIDR if known.
  egress {
    description = "Allow outbound to RDS PostgreSQL in source account"
    from_port   = var.source_rds_port
    to_port     = var.source_rds_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress to Redshift (target) - using VPC CIDR
  egress {
    description = "Allow outbound to Redshift"
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = [var.target_vpc_cidr]
  }

  # Egress for HTTPS (for AWS API calls)
  egress {
    description = "Allow HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-dms-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for Redshift Cluster
resource "aws_security_group" "redshift" {
  name_prefix = "${var.project_name}-${var.environment}-redshift-"
  description = "Security group for Redshift cluster"
  vpc_id      = aws_vpc.target.id

  # Optional: Allow from specific CIDR blocks
  dynamic "ingress" {
    for_each = length(var.allowed_cidr_blocks) > 0 ? [1] : []
    content {
      description = "Allow inbound from allowed CIDR blocks"
      from_port   = 5439
      to_port     = 5439
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
    }
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-redshift-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group Rule to allow DMS to access Redshift
resource "aws_security_group_rule" "redshift_from_dms" {
  type                     = "ingress"
  from_port                = 5439
  to_port                  = 5439
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.dms.id
  security_group_id        = aws_security_group.redshift.id
  description              = "Allow inbound from DMS"
}

# DMS Subnet Group
resource "aws_dms_replication_subnet_group" "dms" {
  replication_subnet_group_id          = "${var.project_name}-${var.environment}-dms-subnet-group"
  replication_subnet_group_description = "Subnet group for DMS replication instance"
  subnet_ids                           = aws_subnet.target_private[*].id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-dms-subnet-group"
    }
  )
}

# Redshift Subnet Group
resource "aws_redshift_subnet_group" "redshift" {
  name       = "${var.project_name}-${var.environment}-redshift-subnet-group"
  subnet_ids = aws_subnet.target_private[*].id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-redshift-subnet-group"
    }
  )
}
