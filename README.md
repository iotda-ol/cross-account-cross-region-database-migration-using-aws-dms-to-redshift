# Cross-Account Cross-Region Database Migration using AWS DMS to Redshift

This repository demonstrates a production-ready cross-account, cross-Region database migration solution using AWS Database Migration Service (DMS). The infrastructure provisions a DMS replication instance in the target AWS account and Region (eu-west-1) to migrate data from Amazon RDS for PostgreSQL (source account) to Amazon Redshift (target account). All infrastructure is defined using Terraform following AWS DEA-C01 certification best practices.

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Migration Process](#migration-process)
- [Monitoring and Operations](#monitoring-and-operations)
- [Security Considerations](#security-considerations)
- [DEA-C01 Best Practices](#dea-c01-best-practices)
- [Troubleshooting](#troubleshooting)
- [Cost Optimization](#cost-optimization)
- [Contributing](#contributing)
- [License](#license)

## 🏗️ Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Source Account (us-east-1)                       │
│                                                                           │
│  ┌─────────────────────────────────────┐                                │
│  │   Amazon RDS for PostgreSQL         │                                │
│  │   - Primary Database                │                                │
│  │   - Logical Replication Enabled     │                                │
│  └─────────────────┬───────────────────┘                                │
│                    │                                                     │
│                    │ Cross-Account                                       │
│                    │ IAM Trust                                           │
└────────────────────┼─────────────────────────────────────────────────────┘
                     │
                     │ SSL/TLS Encrypted Connection
                     │
┌────────────────────▼─────────────────────────────────────────────────────┐
│                      Target Account (eu-west-1)                          │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                          VPC                                     │    │
│  │                                                                  │    │
│  │  ┌────────────────────┐         ┌──────────────────────┐       │    │
│  │  │  DMS Replication   │         │   Amazon Redshift    │       │    │
│  │  │  Instance          │────────▶│   Cluster            │       │    │
│  │  │  - Multi-AZ Ready  │         │   - Multi-Node       │       │    │
│  │  │  - KMS Encrypted   │         │   - KMS Encrypted    │       │    │
│  │  └─────────┬──────────┘         └──────────┬───────────┘       │    │
│  │            │                               │                    │    │
│  │            ▼                               ▼                    │    │
│  │  ┌─────────────────────┐       ┌──────────────────────┐       │    │
│  │  │  S3 Intermediate    │       │  S3 Redshift Logs    │       │    │
│  │  │  Storage            │       │  Bucket              │       │    │
│  │  └─────────────────────┘       └──────────────────────┘       │    │
│  │                                                                 │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    CloudWatch Monitoring                         │   │
│  │  - DMS Task Logs      - Performance Metrics    - Alarms         │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

### Key Components

1. **Source Account (us-east-1)**
   - Amazon RDS for PostgreSQL with logical replication enabled
   - Cross-account IAM role for DMS access

2. **Target Account (eu-west-1)**
   - **VPC Infrastructure**: Private and public subnets across 3 AZs
   - **DMS Replication Instance**: Handles data replication
   - **Amazon Redshift**: Target data warehouse cluster
   - **S3 Buckets**: Intermediate storage and logging
   - **IAM Roles**: Service roles for DMS, Redshift, and cross-account access
   - **KMS Keys**: Encryption for data at rest
   - **CloudWatch**: Monitoring and alerting

## ✨ Features

### Core Functionality
- ✅ **Cross-Account Migration**: Secure data migration across AWS accounts
- ✅ **Cross-Region Replication**: Migrate from us-east-1 to eu-west-1
- ✅ **Full Load and CDC**: Initial full load plus continuous data capture
- ✅ **Encryption**: KMS encryption for data at rest and SSL/TLS in transit
- ✅ **High Availability**: Multi-AZ capable with NAT gateways across AZs

### Infrastructure as Code
- ✅ **Terraform Modules**: Organized, reusable infrastructure code
- ✅ **Version Controlled**: All configurations in source control
- ✅ **Environment Separation**: Support for dev, staging, and prod
- ✅ **Automated Deployment**: Reproducible infrastructure provisioning

### Security
- ✅ **Least Privilege IAM**: Minimal required permissions
- ✅ **Network Isolation**: Private subnets for database resources
- ✅ **Encryption**: KMS encryption for S3, DMS, and Redshift
- ✅ **Security Groups**: Restricted network access
- ✅ **Audit Logging**: CloudWatch logs for DMS and Redshift

### Monitoring
- ✅ **CloudWatch Alarms**: CPU, memory, storage, and health monitoring
- ✅ **DMS Task Logging**: Detailed replication task logs
- ✅ **Redshift Query Logging**: Query performance tracking
- ✅ **Metric Dashboards**: Centralized operational visibility

## 📋 Prerequisites

### Required Tools
- **Terraform**: >= 1.0
- **AWS CLI**: >= 2.0
- **AWS Account**: Two AWS accounts (source and target)
- **Permissions**: Administrator access or sufficient IAM permissions

### AWS Services Knowledge
- Amazon RDS for PostgreSQL
- Amazon Redshift
- AWS Database Migration Service (DMS)
- AWS IAM (roles, policies, trust relationships)
- Amazon VPC and networking
- AWS KMS

### Source Database Requirements
- PostgreSQL 9.4 or later
- Logical replication enabled (`wal_level = logical`)
- Replication slot available
- Sufficient disk space for WAL files

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/iotda-ol/cross-account-cross-region-database-migration-using-aws-dms-to-redshift.git
cd cross-account-cross-region-database-migration-using-aws-dms-to-redshift
```

### 2. Configure AWS Credentials

```bash
# Configure target account credentials
export AWS_PROFILE=target-account

# Or use environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="eu-west-1"
```

### 3. Set Up Source Account

Create a cross-account IAM role in the source account:

```bash
# Create trust policy in source account
aws iam create-role \
  --role-name cross-account-dms-role \
  --assume-role-policy-document file://docs/trust-policy.json \
  --profile source-account

# Attach required policies
aws iam attach-role-policy \
  --role-name cross-account-dms-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonRDSReadOnlyAccess \
  --profile source-account
```

### 4. Configure Variables

```bash
# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your specific values
vi terraform.tfvars
```

### 5. Initialize and Deploy

```bash
# Initialize Terraform
terraform init

# Review the execution plan
terraform plan

# Apply the configuration
terraform apply
```

## ⚙️ Configuration

### Essential Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `source_account_id` | Source AWS account ID | Yes |
| `source_account_role_arn` | IAM role ARN in source account | Yes |
| `source_rds_endpoint` | RDS PostgreSQL endpoint | Yes |
| `source_rds_username` | RDS database username | Yes |
| `source_rds_password` | RDS database password | Yes |
| `redshift_master_password` | Redshift master password | Yes |

### Network Configuration

```hcl
target_vpc_cidr              = "10.0.0.0/16"
target_private_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
target_public_subnet_cidrs   = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
availability_zones           = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
```

### DMS Configuration

```hcl
dms_replication_instance_class = "dms.t3.medium"
dms_allocated_storage          = 100
migration_type                 = "full-load-and-cdc"
```

### Redshift Configuration

```hcl
redshift_node_type       = "dc2.large"
redshift_number_of_nodes = 2
```

## 📦 Deployment

### Step-by-Step Deployment

#### 1. Pre-Deployment Checks

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Validate Terraform configuration
terraform validate

# Check formatting
terraform fmt -check
```

#### 2. Initialize Terraform

```bash
terraform init
```

#### 3. Plan Infrastructure

```bash
# Generate and review execution plan
terraform plan -out=tfplan

# Optional: Save plan to file for review
terraform show tfplan > plan.txt
```

#### 4. Deploy Infrastructure

```bash
# Apply the plan
terraform apply tfplan

# Or apply with auto-approval (not recommended for production)
terraform apply -auto-approve
```

#### 5. Verify Deployment

```bash
# Check DMS replication instance status
aws dms describe-replication-instances \
  --filters "Name=replication-instance-id,Values=dms-replication-instance"

# Check Redshift cluster status
aws redshift describe-clusters \
  --cluster-identifier dms-target-redshift
```

## 🔄 Migration Process

### Phase 1: Pre-Migration

1. **Enable Logical Replication** on source PostgreSQL:
   ```sql
   -- In source RDS PostgreSQL
   ALTER SYSTEM SET wal_level = 'logical';
   -- Restart RDS instance for changes to take effect
   ```

2. **Create Replication Slot**:
   ```sql
   SELECT * FROM pg_create_logical_replication_slot('dms_migration_slot', 'pglogical');
   ```

3. **Verify Source Database**:
   ```bash
   # Test connection
   psql -h source-rds-endpoint -U postgres -d sourcedb -c "SELECT version();"
   ```

### Phase 2: Start Migration

1. **Start DMS Replication Task**:
   ```bash
   aws dms start-replication-task \
     --replication-task-arn <task-arn> \
     --start-replication-task-type start-replication
   ```

2. **Monitor Task Progress**:
   ```bash
   # Check task status
   aws dms describe-replication-tasks \
     --filters "Name=replication-task-arn,Values=<task-arn>"

   # View table statistics
   aws dms describe-table-statistics \
     --replication-task-arn <task-arn>
   ```

### Phase 3: Validation

1. **Verify Data in Redshift**:
   ```sql
   -- Connect to Redshift
   psql -h redshift-endpoint -U admin -d targetdb
   
   -- Check table counts
   SELECT schemaname, tablename, COUNT(*) 
   FROM pg_table_def 
   WHERE schemaname = 'public' 
   GROUP BY schemaname, tablename;
   ```

2. **Compare Row Counts**:
   ```sql
   -- In Redshift
   SELECT COUNT(*) FROM your_table;
   
   -- Compare with source PostgreSQL
   ```

### Phase 4: Cutover

1. **Stop Application Writes** to source database
2. **Wait for CDC to Complete**
3. **Verify Data Consistency**
4. **Switch Application** to Redshift
5. **Stop DMS Replication Task**

## 📊 Monitoring and Operations

### CloudWatch Metrics

#### DMS Metrics
- `CPUUtilization`: Monitor replication instance CPU
- `FreeableMemory`: Available memory
- `FreeStorageSpace`: Available storage
- `NetworkReceiveThroughput`: Inbound network traffic
- `NetworkTransmitThroughput`: Outbound network traffic

#### Redshift Metrics
- `CPUUtilization`: Cluster CPU usage
- `PercentageDiskSpaceUsed`: Disk usage
- `DatabaseConnections`: Active connections
- `HealthStatus`: Cluster health

### Viewing Logs

```bash
# DMS task logs
aws logs tail /aws/dms/dms-migration-dev --follow

# Redshift query logs (from S3)
aws s3 ls s3://dms-migration-dev-redshift-logs-<account-id>/redshift-logs/
```

### Common Monitoring Commands

```bash
# List all DMS replication tasks
aws dms describe-replication-tasks

# Get replication task statistics
aws dms describe-table-statistics \
  --replication-task-arn <task-arn>

# Check Redshift cluster performance
aws redshift describe-cluster-performance \
  --cluster-identifier dms-target-redshift
```

## 🔒 Security Considerations

### Network Security

1. **Private Subnets**: All database resources in private subnets
2. **Security Groups**: Least privilege access rules
3. **No Public Access**: DMS and Redshift not publicly accessible
4. **NAT Gateways**: Secure outbound internet access

### Encryption

1. **Data at Rest**:
   - KMS encryption for DMS replication instance
   - KMS encryption for Redshift cluster
   - S3 bucket encryption (AES-256)

2. **Data in Transit**:
   - SSL/TLS for DMS connections
   - SSL/TLS for Redshift connections

### IAM Security

1. **Service Roles**: Dedicated roles for DMS and Redshift
2. **Least Privilege**: Minimal required permissions
3. **Cross-Account Access**: Secure trust policies
4. **No Hardcoded Credentials**: Use AWS Secrets Manager

### Best Practices

- ✅ Rotate database passwords regularly
- ✅ Enable MFA for AWS accounts
- ✅ Use AWS Secrets Manager for sensitive data
- ✅ Enable CloudTrail for audit logging
- ✅ Implement VPC Flow Logs
- ✅ Regular security assessments

## 📚 DEA-C01 Best Practices

This solution follows AWS Data Analytics Specialty (DEA-C01) certification best practices:

### 1. Collection
- **Multiple Data Sources**: Support for cross-account data ingestion
- **Real-time Ingestion**: CDC for continuous data capture
- **Data Validation**: Automated validation during migration

### 2. Storage and Data Management
- **Data Lake Architecture**: S3 for intermediate storage
- **Data Warehouse**: Redshift for analytics workloads
- **Lifecycle Policies**: Automated data retention and archival
- **Encryption**: KMS encryption for compliance

### 3. Processing
- **ETL/ELT**: DMS handles data transformation during migration
- **Batch Processing**: Full load for initial data migration
- **Stream Processing**: CDC for ongoing changes

### 4. Analysis and Visualization
- **Optimized Storage**: Redshift columnar storage for analytics
- **Query Performance**: Distribution keys and sort keys
- **Concurrency**: WLM configuration for query management

### 5. Security
- **Encryption**: End-to-end encryption
- **Access Control**: IAM policies and roles
- **Network Isolation**: VPC and security groups
- **Audit Logging**: CloudWatch and CloudTrail

### 6. Reliability
- **High Availability**: Multi-AZ capability
- **Backup and Recovery**: Automated snapshots
- **Monitoring**: CloudWatch alarms and metrics
- **Disaster Recovery**: Cross-region deployment

## 🐛 Troubleshooting

### Common Issues

#### DMS Connection Failures

**Problem**: DMS cannot connect to source RDS

**Solutions**:
```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids <sg-id>

# Test connectivity from DMS subnet
# Update source RDS security group to allow DMS security group

# Verify RDS endpoint is correct
aws rds describe-db-instances --db-instance-identifier <instance-id>
```

#### Replication Task Errors

**Problem**: Replication task fails or stops

**Solutions**:
```bash
# Check task logs
aws dms describe-replication-tasks \
  --filters "Name=replication-task-arn,Values=<task-arn>"

# View detailed error messages
aws logs filter-log-events \
  --log-group-name /aws/dms/dms-migration-dev \
  --filter-pattern "ERROR"

# Restart the task
aws dms start-replication-task \
  --replication-task-arn <task-arn> \
  --start-replication-task-type resume-processing
```

#### Redshift Load Failures

**Problem**: Data not loading into Redshift

**Solutions**:
```sql
-- Check STL_LOAD_ERRORS table
SELECT * FROM stl_load_errors ORDER BY starttime DESC LIMIT 10;

-- Check for locked tables
SELECT * FROM svv_transactions WHERE lockable_object_type = 'relation';

-- Verify IAM role permissions
SELECT * FROM svl_s3log ORDER BY query DESC LIMIT 10;
```

#### Performance Issues

**Problem**: Slow replication or query performance

**Solutions**:
```bash
# Scale up DMS instance
aws dms modify-replication-instance \
  --replication-instance-arn <instance-arn> \
  --replication-instance-class dms.c5.2xlarge \
  --apply-immediately

# Resize Redshift cluster
aws redshift modify-cluster \
  --cluster-identifier dms-target-redshift \
  --node-type dc2.8xlarge \
  --number-of-nodes 4
```

### Debugging Tips

1. **Enable Verbose Logging**:
   ```json
   {
     "Logging": {
       "EnableLogging": true,
       "LogComponents": [
         {"Id": "SOURCE_CAPTURE", "Severity": "LOGGER_SEVERITY_DEBUG"}
       ]
     }
   }
   ```

2. **Check Table Mappings**:
   ```bash
   aws dms describe-replication-tasks \
     --filters "Name=replication-task-arn,Values=<task-arn>" \
     --query "ReplicationTasks[0].TableMappings"
   ```

3. **Monitor Network Traffic**:
   ```bash
   # Enable VPC Flow Logs
   aws ec2 create-flow-logs \
     --resource-type VPC \
     --resource-ids <vpc-id> \
     --traffic-type ALL \
     --log-destination-type cloud-watch-logs \
     --log-destination <log-group-arn>
   ```

## 💰 Cost Optimization

### Estimated Monthly Costs (eu-west-1)

| Resource | Configuration | Est. Cost |
|----------|--------------|-----------|
| DMS Instance | dms.t3.medium | ~$140 |
| Redshift Cluster | 2x dc2.large | ~$480 |
| NAT Gateways | 3x NAT Gateway | ~$100 |
| S3 Storage | 100 GB | ~$2 |
| Data Transfer | 1 TB | ~$90 |
| **Total** | | **~$812/month** |

### Cost Reduction Strategies

1. **Right-Size Resources**:
   ```hcl
   # Use smaller instance for development
   dms_replication_instance_class = "dms.t3.small"
   redshift_number_of_nodes = 1
   ```

2. **Schedule Resources**:
   - Stop DMS instance when not in use
   - Pause Redshift cluster during off-hours

3. **Use Spot Instances** (for non-production):
   - Consider EC2 instances with DMS software

4. **Optimize Data Transfer**:
   - Use VPC endpoints to avoid data transfer costs
   - Compress data before transfer

5. **Storage Lifecycle**:
   ```hcl
   # S3 lifecycle rules
   rule {
     id     = "archive-old-logs"
     status = "Enabled"
     transition {
       days          = 30
       storage_class = "GLACIER"
     }
   }
   ```

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📞 Support

For issues and questions:
- Open an issue in GitHub
- Contact the maintainers
- Refer to AWS documentation:
  - [AWS DMS Documentation](https://docs.aws.amazon.com/dms/)
  - [Amazon Redshift Documentation](https://docs.aws.amazon.com/redshift/)
  - [DEA-C01 Exam Guide](https://aws.amazon.com/certification/certified-data-analytics-specialty/)

## 🙏 Acknowledgments

- AWS Documentation and best practices
- Terraform AWS Provider contributors
- DEA-C01 study community

---

**Note**: This is a reference architecture. Always review and adjust configurations based on your specific requirements, compliance needs, and security policies before deploying to production.
