# Deployment Guide

## Quick Start Deployment

This guide provides step-by-step instructions to deploy the cross-account, cross-region DMS migration infrastructure.

## Prerequisites

### 1. Required Tools
- Terraform >= 1.0
- AWS CLI >= 2.0
- Git

Install Terraform:
```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip
unzip terraform_1.6.6_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verify installation
terraform version
```

### 2. AWS Accounts
- Source AWS account (with RDS PostgreSQL)
- Target AWS account (where DMS and Redshift will be deployed)

### 3. Permissions
- Administrator access or equivalent permissions in both accounts
- Ability to create IAM roles, VPCs, DMS resources, Redshift clusters

## Step 1: Source Account Setup

### 1.1 Enable Logical Replication on RDS

```bash
# Connect to AWS source account
export AWS_PROFILE=source-account
export AWS_DEFAULT_REGION=us-east-1

# Create or modify parameter group
aws rds create-db-parameter-group \
  --db-parameter-group-name postgres-logical-replication \
  --db-parameter-group-family postgres14 \
  --description "PostgreSQL with logical replication"

# Set parameters
aws rds modify-db-parameter-group \
  --db-parameter-group-name postgres-logical-replication \
  --parameters \
    "ParameterName=rds.logical_replication,ParameterValue=1,ApplyMethod=pending-reboot" \
    "ParameterName=max_replication_slots,ParameterValue=10,ApplyMethod=pending-reboot" \
    "ParameterName=max_wal_senders,ParameterValue=10,ApplyMethod=pending-reboot"

# Apply to RDS instance
aws rds modify-db-instance \
  --db-instance-identifier your-rds-instance \
  --db-parameter-group-name postgres-logical-replication \
  --apply-immediately

# Reboot instance
aws rds reboot-db-instance \
  --db-instance-identifier your-rds-instance

# Wait for instance to become available
aws rds wait db-instance-available \
  --db-instance-identifier your-rds-instance
```

### 1.2 Create Cross-Account IAM Role

```bash
# Get target account ID
TARGET_ACCOUNT_ID="987654321098"  # Replace with your target account ID

# Create trust policy
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${TARGET_ACCOUNT_ID}:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "dms-migration-external-id-12345"
        }
      }
    }
  ]
}
EOF

# Create role
aws iam create-role \
  --role-name cross-account-dms-source-role \
  --assume-role-policy-document file://trust-policy.json

# Create permissions policy
cat > permissions-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "rds:DescribeDBInstances",
        "rds:DescribeDBClusters",
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeNetworkInterfaces"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Attach policy
aws iam put-role-policy \
  --role-name cross-account-dms-source-role \
  --policy-name CrossAccountDMSPolicy \
  --policy-document file://permissions-policy.json

# Get role ARN (save this!)
aws iam get-role \
  --role-name cross-account-dms-source-role \
  --query 'Role.Arn' \
  --output text
```

### 1.3 Update RDS Security Group

```bash
# Get RDS security group ID
RDS_SG_ID=$(aws rds describe-db-instances \
  --db-instance-identifier your-rds-instance \
  --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
  --output text)

# Add rule to allow DMS access (replace with target VPC CIDR or use 0.0.0.0/0 temporarily)
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG_ID \
  --protocol tcp \
  --port 5432 \
  --cidr 10.0.0.0/16  # Target VPC CIDR
```

### 1.4 Create Replication Slot

```bash
# Connect to PostgreSQL
psql -h your-rds-endpoint.region.rds.amazonaws.com -U postgres -d sourcedb

# Create replication slot
SELECT * FROM pg_create_logical_replication_slot('dms_migration_slot', 'pglogical');

# Verify
SELECT * FROM pg_replication_slots;

# Exit
\q
```

## Step 2: Target Account Setup

### 2.1 Clone Repository

```bash
git clone https://github.com/iotda-ol/cross-account-cross-region-database-migration-using-aws-dms-to-redshift.git
cd cross-account-cross-region-database-migration-using-aws-dms-to-redshift
```

### 2.2 Configure AWS Credentials

```bash
# Configure target account
export AWS_PROFILE=target-account
export AWS_DEFAULT_REGION=eu-west-1

# Or use environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"

# Verify credentials
aws sts get-caller-identity
```

### 2.3 Create terraform.tfvars

```bash
# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vi terraform.tfvars
```

**Important values to update:**
```hcl
# Cross-Account
source_account_id       = "123456789012"  # Your source account ID
source_account_role_arn = "arn:aws:iam::123456789012:role/cross-account-dms-source-role"

# Source RDS
source_rds_endpoint      = "your-rds.abcdefgh.us-east-1.rds.amazonaws.com"
source_rds_database_name = "sourcedb"
source_rds_username      = "postgres"
source_rds_password      = "YourPassword123!"

# Redshift
redshift_master_password = "YourRedshiftPassword456!"
```

### 2.4 Initialize Terraform

```bash
# Initialize
terraform init

# Validate
terraform validate

# Format
terraform fmt
```

## Step 3: Deploy Infrastructure

### 3.1 Plan Deployment

```bash
# Generate plan
terraform plan -out=tfplan

# Review the plan carefully
terraform show tfplan

# Optional: Save plan to file for review
terraform show -json tfplan | jq > plan.json
```

**Expected resources to be created:**
- ~50 resources total including:
  - 1 VPC with subnets, route tables, NAT gateways
  - 7 security groups and rules
  - 1 DMS replication instance
  - 2 DMS endpoints (source and target)
  - 1 DMS replication task
  - 1 Redshift cluster
  - 2 S3 buckets
  - Multiple IAM roles and policies
  - 2 KMS keys
  - CloudWatch alarms

### 3.2 Apply Configuration

```bash
# Apply the plan
terraform apply tfplan

# This will take 15-20 minutes to complete
# DMS replication instance: ~5 minutes
# Redshift cluster: ~10-15 minutes
```

### 3.3 Verify Deployment

```bash
# Check DMS replication instance
aws dms describe-replication-instances \
  --filters "Name=replication-instance-id,Values=dms-replication-instance"

# Check Redshift cluster
aws redshift describe-clusters \
  --cluster-identifier dms-target-redshift

# Check endpoints
aws dms describe-endpoints

# Check replication task
aws dms describe-replication-tasks
```

## Step 4: Test Connectivity

### 4.1 Test Source Endpoint

```bash
# Get endpoint ARN
SOURCE_ENDPOINT_ARN=$(terraform output -raw dms_source_endpoint_arn)

# Get replication instance ARN
REPLICATION_INSTANCE_ARN=$(terraform output -raw dms_replication_instance_arn)

# Test connection
aws dms test-connection \
  --replication-instance-arn $REPLICATION_INSTANCE_ARN \
  --endpoint-arn $SOURCE_ENDPOINT_ARN

# Check status (wait 1-2 minutes)
aws dms describe-connections \
  --filters "Name=endpoint-arn,Values=$SOURCE_ENDPOINT_ARN"
```

### 4.2 Test Target Endpoint

```bash
# Get target endpoint ARN
TARGET_ENDPOINT_ARN=$(terraform output -raw dms_target_endpoint_arn)

# Test connection
aws dms test-connection \
  --replication-instance-arn $REPLICATION_INSTANCE_ARN \
  --endpoint-arn $TARGET_ENDPOINT_ARN

# Check status
aws dms describe-connections \
  --filters "Name=endpoint-arn,Values=$TARGET_ENDPOINT_ARN"
```

Both connections should show status: `successful`

## Step 5: Start Migration

### 5.1 Start Replication Task

```bash
# Get task ARN
TASK_ARN=$(terraform output -raw dms_replication_task_arn)

# Start the task
aws dms start-replication-task \
  --replication-task-arn $TASK_ARN \
  --start-replication-task-type start-replication

# Monitor status
watch -n 10 "aws dms describe-replication-tasks \
  --filters 'Name=replication-task-arn,Values=$TASK_ARN' \
  --query 'ReplicationTasks[0].[Status,ReplicationTaskStats]'"
```

### 5.2 Monitor Progress

```bash
# View table statistics
aws dms describe-table-statistics \
  --replication-task-arn $TASK_ARN

# View CloudWatch logs
aws logs tail /aws/dms/dms-migration-dev --follow

# Check DMS metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/DMS \
  --metric-name CDCLatencyTarget \
  --dimensions Name=ReplicationInstanceIdentifier,Value=dms-replication-instance \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### 5.3 Verify Data in Redshift

```bash
# Get Redshift endpoint
REDSHIFT_HOST=$(terraform output -raw redshift_cluster_hostname)

# Connect to Redshift
psql -h $REDSHIFT_HOST -U admin -d targetdb -p 5439

# Check tables
\dt

# Check row counts
SELECT schemaname, tablename, COUNT(*)
FROM pg_table_def
WHERE schemaname = 'public'
GROUP BY schemaname, tablename;

# Exit
\q
```

## Step 6: Post-Deployment

### 6.1 Save Outputs

```bash
# Save all outputs
terraform output > outputs.txt

# Get specific outputs
echo "DMS Instance ARN: $(terraform output dms_replication_instance_arn)"
echo "Redshift Endpoint: $(terraform output redshift_cluster_endpoint)"
echo "S3 Bucket: $(terraform output dms_intermediate_s3_bucket)"
```

### 6.2 Configure Monitoring

```bash
# Create SNS topic for alerts
SNS_TOPIC_ARN=$(aws sns create-topic \
  --name dms-migration-alerts \
  --query 'TopicArn' \
  --output text)

# Subscribe to notifications
aws sns subscribe \
  --topic-arn $SNS_TOPIC_ARN \
  --protocol email \
  --notification-endpoint your-email@example.com

# Confirm subscription (check email)

# Update alarms to use SNS
aws cloudwatch put-metric-alarm \
  --alarm-name dms-replication-lag \
  --alarm-actions $SNS_TOPIC_ARN \
  --metric-name CDCLatencyTarget \
  --namespace AWS/DMS \
  --statistic Average \
  --period 300 \
  --threshold 300 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2
```

### 6.3 Document Configuration

Create a document with:
- Source account details
- Target account details
- Deployed resource ARNs
- Access credentials locations
- Monitoring dashboard links
- Escalation contacts

## Troubleshooting Deployment

### Issue: Terraform Apply Fails

**Check AWS credentials:**
```bash
aws sts get-caller-identity
```

**Check Terraform state:**
```bash
terraform show
```

**Retry with specific resource:**
```bash
terraform apply -target=aws_vpc.target
```

### Issue: DMS Instance Creation Fails

**Check service-linked roles:**
```bash
# Check if roles exist
aws iam get-role --role-name dms-vpc-role
aws iam get-role --role-name dms-cloudwatch-logs-role

# Create if missing
aws iam create-service-linked-role --aws-service-name dms.amazonaws.com
```

### Issue: Redshift Cluster Creation Fails

**Check KMS key policy:**
```bash
aws kms get-key-policy \
  --key-id $(terraform output kms_key_id) \
  --policy-name default
```

**Check subnet group:**
```bash
aws redshift describe-cluster-subnet-groups
```

### Issue: Connection Tests Fail

**Check security groups:**
```bash
# DMS security group
aws ec2 describe-security-groups \
  --group-ids $(terraform output dms_security_group_id)

# Redshift security group
aws ec2 describe-security-groups \
  --group-ids $(terraform output redshift_security_group_id)
```

**Check network connectivity:**
```bash
# Verify NAT gateways
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=$(terraform output vpc_id)"

# Check route tables
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$(terraform output vpc_id)"
```

## Rollback Procedure

### Graceful Rollback

```bash
# 1. Stop replication task
aws dms stop-replication-task \
  --replication-task-arn $TASK_ARN

# 2. Wait for task to stop
aws dms wait replication-task-stopped \
  --filters "Name=replication-task-arn,Values=$TASK_ARN"

# 3. Destroy infrastructure
terraform destroy

# Confirm: yes
```

### Emergency Rollback

```bash
# Delete replication task immediately
aws dms delete-replication-task \
  --replication-task-arn $TASK_ARN

# Force destroy with Terraform
terraform destroy -auto-approve
```

## Cost Estimation

### Monthly Costs (eu-west-1)

| Resource | Configuration | Est. Cost/Month |
|----------|--------------|-----------------|
| DMS Instance | dms.t3.medium | $140 |
| Redshift | 2x dc2.large | $480 |
| NAT Gateways | 3x | $100 |
| S3 Storage | 100 GB | $2 |
| Data Transfer | 1 TB | $90 |
| KMS Keys | 2x | $2 |
| **Total** | | **~$814** |

### Cost Optimization

**For Development:**
```hcl
# In terraform.tfvars
dms_replication_instance_class = "dms.t3.small"    # $70/month
redshift_number_of_nodes = 1                        # $240/month
# Use single NAT Gateway                            # $33/month
# Total: ~$345/month (57% savings)
```

**Stop when not in use:**
```bash
# Pause Redshift cluster
aws redshift pause-cluster --cluster-identifier dms-target-redshift

# Resume when needed
aws redshift resume-cluster --cluster-identifier dms-target-redshift
```

## Next Steps

1. **Configure Application Access**: Update application connection strings to use Redshift
2. **Set Up Backups**: Configure cross-region snapshot copies
3. **Optimize Queries**: Create distribution keys and sort keys
4. **Set Up BI Tools**: Connect Tableau, QuickSight, or other tools
5. **Implement Monitoring**: Create CloudWatch dashboards
6. **Schedule Maintenance**: Plan for updates and optimizations
7. **Document Runbooks**: Create operational procedures

## Support Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS DMS Documentation](https://docs.aws.amazon.com/dms/)
- [Amazon Redshift Documentation](https://docs.aws.amazon.com/redshift/)
- Repository Issues: Create an issue for problems or questions

## Cleanup

When migration is complete and no longer needed:

```bash
# 1. Export data if needed
aws redshift create-cluster-snapshot \
  --cluster-identifier dms-target-redshift \
  --snapshot-identifier final-snapshot-$(date +%Y%m%d)

# 2. Delete replication slot in source RDS
psql -h source-rds-endpoint -U postgres -d sourcedb \
  -c "SELECT pg_drop_replication_slot('dms_migration_slot');"

# 3. Remove cross-account role in source account
aws iam delete-role-policy \
  --role-name cross-account-dms-source-role \
  --policy-name CrossAccountDMSPolicy \
  --profile source-account

aws iam delete-role \
  --role-name cross-account-dms-source-role \
  --profile source-account

# 4. Destroy target infrastructure
terraform destroy

# 5. Clean up local files
rm -rf .terraform terraform.tfstate* tfplan *.json
```
