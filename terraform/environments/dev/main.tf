# Main Terraform configuration for dev environment
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment for remote state
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "dms-migration/dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# AWS Provider for Target Account
provider "aws" {
  region = var.target_region
  
  default_tags {
    tags = var.tags
  }
}

# AWS Provider for Source Account (aliased)
provider "aws" {
  alias  = "source"
  region = var.source_region
  
  # Assume role in source account if needed
  # assume_role {
  #   role_arn = "arn:aws:iam::${var.source_account_id}:role/TerraformRole"
  # }
  
  default_tags {
    tags = var.tags
  }
}

# Networking Module
module "networking" {
  source = "../../modules/networking"

  project_name           = var.project_name
  environment            = var.environment
  vpc_cidr               = var.vpc_cidr
  availability_zones     = var.availability_zones
  public_subnet_cidrs    = var.public_subnet_cidrs
  private_subnet_cidrs   = var.private_subnet_cidrs
  database_subnet_cidrs  = var.database_subnet_cidrs
  enable_nat_gateway     = true
  single_nat_gateway     = true
  enable_flow_logs       = true

  tags = var.tags
}

# IAM Module
module "iam" {
  source = "../../modules/iam"

  project_name      = var.project_name
  environment       = var.environment
  source_account_id = var.source_account_id
  target_account_id = var.target_account_id
  s3_bucket_arn     = module.s3.bucket_arn

  tags = var.tags
}

# S3 Module
module "s3" {
  source = "../../modules/s3"

  project_name = var.project_name
  environment  = var.environment

  tags = var.tags
}

# RDS Module (Source Database)
module "rds" {
  source = "../../modules/rds"

  project_name    = var.project_name
  environment     = var.environment
  db_name         = var.rds_db_name
  db_username     = var.rds_username
  db_password     = var.rds_password
  instance_class  = var.rds_instance_class
  allocated_storage = var.rds_allocated_storage
  engine_version  = var.rds_engine_version
  vpc_id          = module.networking.vpc_id
  subnet_ids      = module.networking.database_subnet_ids
  multi_az        = var.rds_multi_az

  tags = var.tags
}

# Redshift Module (Target Database)
module "redshift" {
  source = "../../modules/redshift"

  project_name      = var.project_name
  environment       = var.environment
  cluster_identifier = "${var.project_name}-${var.environment}-redshift"
  database_name     = var.redshift_database_name
  master_username   = var.redshift_master_username
  master_password   = var.redshift_master_password
  node_type         = var.redshift_node_type
  number_of_nodes   = var.redshift_number_of_nodes
  vpc_id            = module.networking.vpc_id
  subnet_ids        = module.networking.database_subnet_ids
  logging_bucket_name = module.s3.bucket_id

  tags = var.tags
}

# DMS Module
module "dms" {
  source = "../../modules/dms"

  project_name               = var.project_name
  environment                = var.environment
  replication_instance_id    = var.dms_replication_instance_id
  replication_instance_class = var.dms_instance_class
  allocated_storage          = var.dms_allocated_storage
  engine_version             = var.dms_engine_version
  vpc_id                     = module.networking.vpc_id
  subnet_ids                 = module.networking.private_subnet_ids
  multi_az                   = var.dms_multi_az

  tags = var.tags

  depends_on = [
    module.iam
  ]
}

# CloudWatch Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"

  project_name = var.project_name
  environment  = var.environment
  dms_task_arns = []  # Add task ARNs after DMS tasks are created

  tags = var.tags
}
