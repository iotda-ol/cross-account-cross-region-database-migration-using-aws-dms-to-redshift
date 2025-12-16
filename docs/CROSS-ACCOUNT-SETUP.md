# Cross-Account Setup Guide

## Overview

This guide provides step-by-step instructions for configuring cross-account access required for the DMS migration solution.

## Architecture

```
┌─────────────────────────────────────────┐
│      Source Account (us-east-1)         │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │   Amazon RDS PostgreSQL          │  │
│  │   - Production Database          │  │
│  └──────────────┬───────────────────┘  │
│                 │                       │
│  ┌──────────────▼───────────────────┐  │
│  │   IAM Role:                      │  │
│  │   cross-account-dms-source-role  │  │
│  │   Trust: Target Account          │  │
│  └──────────────────────────────────┘  │
│                                         │
└────────────────┬────────────────────────┘
                 │
                 │ Assume Role
                 │
┌────────────────▼────────────────────────┐
│     Target Account (eu-west-1)          │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │   DMS Replication Instance       │  │
│  │   - Assumes Source Role          │  │
│  │   - Connects to Source RDS       │  │
│  └──────────────┬───────────────────┘  │
│                 │                       │
│  ┌──────────────▼───────────────────┐  │
│  │   Amazon Redshift                │  │
│  │   - Target Data Warehouse        │  │
│  └──────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

## Prerequisites

### Required Information

Before starting, gather the following information:

- **Source Account ID**: AWS account ID where RDS PostgreSQL is located
- **Target Account ID**: AWS account ID where DMS and Redshift will be deployed
- **Source RDS Details**: Endpoint, port, database name, credentials
- **Network Information**: VPC IDs, subnet IDs, security group IDs in both accounts

### Required Permissions

**Source Account**:
- IAM permissions to create roles and policies
- RDS permissions to modify security groups

**Target Account**:
- Full administrator access or permissions to create:
  - VPC and networking resources
  - DMS resources
  - Redshift clusters
  - IAM roles and policies
  - KMS keys
  - S3 buckets

## Step 1: Configure Source Account

### 1.1 Create IAM Role in Source Account

Create a trust policy file:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::TARGET_ACCOUNT_ID:root"
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
```

**Important**: Replace `TARGET_ACCOUNT_ID` with your actual target account ID and use a unique external ID.

Create the role:

```bash
# Save the trust policy to a file
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::TARGET_ACCOUNT_ID:root"
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

# Create the role
aws iam create-role \
  --role-name cross-account-dms-source-role \
  --assume-role-policy-document file://trust-policy.json \
  --description "Role for cross-account DMS access to source RDS" \
  --profile source-account \
  --region us-east-1
```

### 1.2 Create and Attach IAM Policy

Create the permissions policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "RDSDescribeAccess",
      "Effect": "Allow",
      "Action": [
        "rds:DescribeDBInstances",
        "rds:DescribeDBClusters",
        "rds:DescribeDBSubnetGroups"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2NetworkAccess",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeAvailabilityZones"
      ],
      "Resource": "*"
    }
  ]
}
```

Attach the policy:

```bash
# Create the policy
cat > permissions-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "RDSDescribeAccess",
      "Effect": "Allow",
      "Action": [
        "rds:DescribeDBInstances",
        "rds:DescribeDBClusters",
        "rds:DescribeDBSubnetGroups"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2NetworkAccess",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeAvailabilityZones"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Create and attach inline policy
aws iam put-role-policy \
  --role-name cross-account-dms-source-role \
  --policy-name CrossAccountDMSPolicy \
  --policy-document file://permissions-policy.json \
  --profile source-account \
  --region us-east-1
```

### 1.3 Note the Role ARN

Get the role ARN:

```bash
aws iam get-role \
  --role-name cross-account-dms-source-role \
  --query 'Role.Arn' \
  --output text \
  --profile source-account \
  --region us-east-1
```

**Save this ARN** - you'll need it for the Terraform configuration in the target account.

Example output:
```
arn:aws:iam::123456789012:role/cross-account-dms-source-role
```

### 1.4 Configure Source RDS Security Group

Add inbound rule to allow DMS access:

```bash
# Get the target account's VPC CIDR or DMS security group ID
# For this example, we'll use CIDR blocks

# Add inbound rule to RDS security group
aws ec2 authorize-security-group-ingress \
  --group-id sg-source-rds-xxxxxxxxx \
  --protocol tcp \
  --port 5432 \
  --cidr 10.0.0.0/16 \
  --profile source-account \
  --region us-east-1
```

**Note**: In production, use more specific CIDR blocks or consider VPC peering.

### 1.5 Enable Logical Replication on Source RDS

Modify the RDS parameter group:

```bash
# Create custom parameter group if not exists
aws rds create-db-parameter-group \
  --db-parameter-group-name postgres-logical-replication \
  --db-parameter-group-family postgres14 \
  --description "PostgreSQL with logical replication enabled" \
  --profile source-account \
  --region us-east-1

# Set required parameters
aws rds modify-db-parameter-group \
  --db-parameter-group-name postgres-logical-replication \
  --parameters \
    "ParameterName=rds.logical_replication,ParameterValue=1,ApplyMethod=pending-reboot" \
    "ParameterName=max_replication_slots,ParameterValue=10,ApplyMethod=pending-reboot" \
    "ParameterName=max_wal_senders,ParameterValue=10,ApplyMethod=pending-reboot" \
  --profile source-account \
  --region us-east-1

# Apply parameter group to RDS instance
aws rds modify-db-instance \
  --db-instance-identifier source-rds-postgres \
  --db-parameter-group-name postgres-logical-replication \
  --apply-immediately \
  --profile source-account \
  --region us-east-1

# Reboot the instance for changes to take effect
aws rds reboot-db-instance \
  --db-instance-identifier source-rds-postgres \
  --profile source-account \
  --region us-east-1
```

### 1.6 Verify Logical Replication

After reboot, connect to PostgreSQL and verify:

```sql
-- Connect to source RDS
psql -h source-rds-endpoint -U postgres -d sourcedb

-- Check wal_level
SHOW wal_level;
-- Should return: logical

-- Check max_replication_slots
SHOW max_replication_slots;
-- Should return: 10

-- Check max_wal_senders
SHOW max_wal_senders;
-- Should return: 10

-- Create replication slot (will be used by DMS)
SELECT * FROM pg_create_logical_replication_slot('dms_migration_slot', 'pglogical');
```

## Step 2: Configure Target Account

### 2.1 Configure AWS CLI Profile

```bash
# Configure target account profile
aws configure --profile target-account
# Enter Access Key ID
# Enter Secret Access Key
# Enter default region: eu-west-1
# Enter default output format: json
```

### 2.2 Prepare Terraform Variables

Create `terraform.tfvars` file:

```hcl
# Environment
environment  = "dev"
project_name = "dms-migration"

# Regions
target_region = "eu-west-1"
source_region = "us-east-1"

# Cross-Account Configuration
source_account_id       = "123456789012"  # Source account ID
source_account_role_arn = "arn:aws:iam::123456789012:role/cross-account-dms-source-role"

# Source RDS Details
source_rds_endpoint      = "source-rds.abcdefgh.us-east-1.rds.amazonaws.com"
source_rds_port          = 5432
source_rds_database_name = "sourcedb"
source_rds_username      = "postgres"
source_rds_password      = "YourSecurePassword123!"

# Redshift Configuration
redshift_master_password = "YourRedshiftPassword456!"

# Additional configurations...
```

**Security Note**: Never commit `terraform.tfvars` to version control. Use AWS Secrets Manager or Parameter Store for production.

### 2.3 Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment
terraform plan -out=tfplan

# Review the plan carefully

# Apply
terraform apply tfplan
```

### 2.4 Verify Deployment

Check DMS replication instance:

```bash
aws dms describe-replication-instances \
  --filters "Name=replication-instance-id,Values=dms-replication-instance" \
  --profile target-account \
  --region eu-west-1
```

Check Redshift cluster:

```bash
aws redshift describe-clusters \
  --cluster-identifier dms-target-redshift \
  --profile target-account \
  --region eu-west-1
```

## Step 3: Test Cross-Account Connectivity

### 3.1 Test Role Assumption

From target account, test assuming the source account role:

```bash
aws sts assume-role \
  --role-arn "arn:aws:iam::123456789012:role/cross-account-dms-source-role" \
  --role-session-name "test-session" \
  --external-id "dms-migration-external-id-12345" \
  --profile target-account
```

Expected output should include temporary credentials.

### 3.2 Test DMS Source Endpoint

Test the DMS source endpoint connection:

```bash
# Get the endpoint ARN
SOURCE_ENDPOINT_ARN=$(aws dms describe-endpoints \
  --filters "Name=endpoint-id,Values=dms-migration-dev-source-rds" \
  --query "Endpoints[0].EndpointArn" \
  --output text \
  --profile target-account \
  --region eu-west-1)

# Get the replication instance ARN
REPLICATION_INSTANCE_ARN=$(aws dms describe-replication-instances \
  --filters "Name=replication-instance-id,Values=dms-replication-instance" \
  --query "ReplicationInstances[0].ReplicationInstanceArn" \
  --output text \
  --profile target-account \
  --region eu-west-1)

# Test the connection
aws dms test-connection \
  --replication-instance-arn "$REPLICATION_INSTANCE_ARN" \
  --endpoint-arn "$SOURCE_ENDPOINT_ARN" \
  --profile target-account \
  --region eu-west-1
```

Check connection status:

```bash
aws dms describe-connections \
  --filters "Name=endpoint-arn,Values=$SOURCE_ENDPOINT_ARN" \
  --profile target-account \
  --region eu-west-1
```

Connection status should be `successful`.

### 3.3 Test DMS Target Endpoint

```bash
# Get the target endpoint ARN
TARGET_ENDPOINT_ARN=$(aws dms describe-endpoints \
  --filters "Name=endpoint-id,Values=dms-migration-dev-target-redshift" \
  --query "Endpoints[0].EndpointArn" \
  --output text \
  --profile target-account \
  --region eu-west-1)

# Test the connection
aws dms test-connection \
  --replication-instance-arn "$REPLICATION_INSTANCE_ARN" \
  --endpoint-arn "$TARGET_ENDPOINT_ARN" \
  --profile target-account \
  --region eu-west-1
```

## Step 4: Network Connectivity Options

### Option 1: Internet-Based Connection (Default)

**Pros**:
- Simple to set up
- No additional AWS resources required
- Works across any accounts and regions

**Cons**:
- Data traverses public internet (encrypted via SSL/TLS)
- Higher latency
- Data transfer costs

**Configuration**:
- Source RDS must be publicly accessible OR use NAT Gateway
- DMS uses NAT Gateway for outbound connections
- Security groups allow traffic from DMS CIDR

### Option 2: VPC Peering

**Pros**:
- Private connectivity
- Lower latency
- Reduced data transfer costs

**Cons**:
- More complex setup
- CIDR blocks cannot overlap
- Requires routing configuration

**Setup Steps**:

1. Create VPC peering connection:

```bash
# From target account, create peering connection
PEERING_ID=$(aws ec2 create-vpc-peering-connection \
  --vpc-id vpc-target-xxxxxx \
  --peer-vpc-id vpc-source-xxxxxx \
  --peer-owner-id 123456789012 \
  --peer-region us-east-1 \
  --profile target-account \
  --region eu-west-1 \
  --query 'VpcPeeringConnection.VpcPeeringConnectionId' \
  --output text)

# From source account, accept peering connection
aws ec2 accept-vpc-peering-connection \
  --vpc-peering-connection-id "$PEERING_ID" \
  --profile source-account \
  --region us-east-1
```

2. Update route tables:

```bash
# In target account
aws ec2 create-route \
  --route-table-id rtb-target-private-xxxxxx \
  --destination-cidr-block 172.31.0.0/16 \
  --vpc-peering-connection-id "$PEERING_ID" \
  --profile target-account \
  --region eu-west-1

# In source account
aws ec2 create-route \
  --route-table-id rtb-source-xxxxxx \
  --destination-cidr-block 10.0.0.0/16 \
  --vpc-peering-connection-id "$PEERING_ID" \
  --profile source-account \
  --region us-east-1
```

3. Update security groups to allow traffic from peered VPC CIDR.

### Option 3: AWS PrivateLink

**Pros**:
- Most secure option
- Private connectivity
- No VPC peering required
- Supports overlapping CIDRs

**Cons**:
- Most complex to set up
- Additional costs for endpoint
- Limited to same region (use Transit Gateway for cross-region)

**Setup**:
Requires AWS Transit Gateway or VPN for cross-region connectivity.

### Option 4: VPN Connection

**Pros**:
- Secure tunnel
- Works across regions
- No CIDR overlap issues

**Cons**:
- More complex setup
- Additional costs
- Requires VPN gateway configuration

## Step 5: Security Hardening

### 5.1 Rotate Credentials

Schedule regular credential rotation:

```bash
# Rotate RDS password
aws rds modify-db-instance \
  --db-instance-identifier source-rds-postgres \
  --master-user-password "NewSecurePassword123!" \
  --apply-immediately \
  --profile source-account \
  --region us-east-1

# Update DMS endpoint
aws dms modify-endpoint \
  --endpoint-arn "$SOURCE_ENDPOINT_ARN" \
  --password "NewSecurePassword123!" \
  --profile target-account \
  --region eu-west-1
```

### 5.2 Enable MFA for IAM Users

```bash
# Enable MFA for users with console access
aws iam enable-mfa-device \
  --user-name admin-user \
  --serial-number arn:aws:iam::123456789012:mfa/admin-user \
  --authentication-code-1 123456 \
  --authentication-code-2 789012 \
  --profile source-account
```

### 5.3 Enable CloudTrail

Ensure CloudTrail is enabled in both accounts:

```bash
# Source account
aws cloudtrail create-trail \
  --name source-account-trail \
  --s3-bucket-name source-cloudtrail-logs \
  --is-multi-region-trail \
  --profile source-account

aws cloudtrail start-logging \
  --name source-account-trail \
  --profile source-account

# Target account
aws cloudtrail create-trail \
  --name target-account-trail \
  --s3-bucket-name target-cloudtrail-logs \
  --is-multi-region-trail \
  --profile target-account

aws cloudtrail start-logging \
  --name target-account-trail \
  --profile target-account
```

### 5.4 Use AWS Secrets Manager

Migrate credentials to Secrets Manager:

```bash
# Store RDS credentials
aws secretsmanager create-secret \
  --name dms/source-rds/credentials \
  --description "Source RDS PostgreSQL credentials" \
  --secret-string '{
    "username":"postgres",
    "password":"YourSecurePassword123!",
    "engine":"postgres",
    "host":"source-rds.abcdefgh.us-east-1.rds.amazonaws.com",
    "port":5432,
    "dbname":"sourcedb"
  }' \
  --profile target-account \
  --region eu-west-1
```

## Step 6: Monitoring and Alerting

### 6.1 Set Up CloudWatch Dashboards

Create a dashboard for cross-account monitoring:

```bash
aws cloudwatch put-dashboard \
  --dashboard-name DMS-Cross-Account-Migration \
  --dashboard-body file://dashboard.json \
  --profile target-account \
  --region eu-west-1
```

### 6.2 Configure SNS Notifications

```bash
# Create SNS topic
TOPIC_ARN=$(aws sns create-topic \
  --name dms-migration-alerts \
  --profile target-account \
  --region eu-west-1 \
  --query 'TopicArn' \
  --output text)

# Subscribe email
aws sns subscribe \
  --topic-arn "$TOPIC_ARN" \
  --protocol email \
  --notification-endpoint admin@example.com \
  --profile target-account \
  --region eu-west-1

# Add subscription to CloudWatch alarms
aws cloudwatch put-metric-alarm \
  --alarm-name dms-replication-lag \
  --alarm-actions "$TOPIC_ARN" \
  --profile target-account \
  --region eu-west-1
```

## Troubleshooting

### Issue: Role Assumption Fails

**Symptoms**: Error assuming cross-account role

**Solutions**:
```bash
# Verify role exists
aws iam get-role \
  --role-name cross-account-dms-source-role \
  --profile source-account

# Check trust policy
aws iam get-role \
  --role-name cross-account-dms-source-role \
  --query 'Role.AssumeRolePolicyDocument' \
  --profile source-account

# Verify external ID matches
```

### Issue: DMS Cannot Connect to Source RDS

**Symptoms**: Connection test fails

**Solutions**:
```bash
# Check RDS security group
aws ec2 describe-security-groups \
  --group-ids sg-source-rds-xxxxxx \
  --profile source-account \
  --region us-east-1

# Verify RDS endpoint is accessible
nslookup source-rds.abcdefgh.us-east-1.rds.amazonaws.com

# Check if RDS is in private subnet (requires NAT or VPC peering)
aws rds describe-db-instances \
  --db-instance-identifier source-rds-postgres \
  --query 'DBInstances[0].PubliclyAccessible' \
  --profile source-account \
  --region us-east-1
```

### Issue: High Replication Lag

**Symptoms**: CDC lag increasing

**Solutions**:
```bash
# Check DMS instance resources
aws dms describe-replication-instances \
  --profile target-account \
  --region eu-west-1

# Consider scaling up
aws dms modify-replication-instance \
  --replication-instance-arn "$REPLICATION_INSTANCE_ARN" \
  --replication-instance-class dms.c5.2xlarge \
  --apply-immediately \
  --profile target-account \
  --region eu-west-1

# Check source database load
# Verify network bandwidth
```

## Best Practices

### Security
- ✅ Always use external IDs for cross-account roles
- ✅ Use least privilege IAM policies
- ✅ Enable MFA for all human users
- ✅ Rotate credentials regularly
- ✅ Use AWS Secrets Manager for credentials
- ✅ Enable CloudTrail in all accounts
- ✅ Use VPC peering or PrivateLink for production

### Performance
- ✅ Right-size DMS instance based on workload
- ✅ Use VPC peering for lower latency
- ✅ Monitor replication lag continuously
- ✅ Optimize PostgreSQL for logical replication
- ✅ Use parallel processing when possible

### Cost Optimization
- ✅ Use appropriate instance sizes
- ✅ Stop DMS instance when not in use (non-prod)
- ✅ Use VPC endpoints to avoid data transfer costs
- ✅ Clean up resources after migration
- ✅ Use S3 lifecycle policies for logs

### Operations
- ✅ Document all configurations
- ✅ Test disaster recovery procedures
- ✅ Set up monitoring and alerting
- ✅ Regular security audits
- ✅ Keep CloudTrail logs for compliance

## Summary Checklist

- [ ] Source account role created and configured
- [ ] Source RDS security group updated
- [ ] Logical replication enabled on source RDS
- [ ] Target account infrastructure deployed
- [ ] Cross-account role assumption tested
- [ ] DMS endpoints connection tested
- [ ] Network connectivity verified
- [ ] Monitoring and alerting configured
- [ ] Security hardening completed
- [ ] Documentation updated
- [ ] Team trained on operations

## Additional Resources

- [AWS DMS Cross-Account Documentation](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Security.html#CHAP_Security.FineGrainedAccess)
- [IAM Cross-Account Access](https://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_cross-account-with-roles.html)
- [VPC Peering Guide](https://docs.aws.amazon.com/vpc/latest/peering/what-is-vpc-peering.html)
- [PostgreSQL Logical Replication](https://www.postgresql.org/docs/current/logical-replication.html)
