# Security Guide

## Overview

This document details the security architecture, controls, and best practices implemented in the cross-account database migration solution.

## Security Principles

### 1. Least Privilege Access
All IAM roles and policies grant only the minimum permissions necessary for operation.

### 2. Defense in Depth
Multiple layers of security controls protect data and resources.

### 3. Encryption Everywhere
Data is encrypted both at rest and in transit using industry-standard encryption.

### 4. Audit and Monitoring
All access and actions are logged for security analysis and compliance.

### 5. Network Isolation
Database resources are isolated in private subnets with no direct internet access.

## Network Security

### VPC Configuration

#### Network Segmentation

**Private Subnets**:
- Purpose: Host DMS replication instance and Redshift cluster
- Internet Access: Through NAT Gateways only
- Public IPs: None assigned
- Route Tables: Route to NAT Gateway for outbound traffic

**Public Subnets**:
- Purpose: Host NAT Gateways
- Internet Access: Through Internet Gateway
- Resources: NAT Gateways, potential bastion hosts
- Route Tables: Route to Internet Gateway

#### Security Groups

**DMS Security Group Rules**:
```hcl
# Egress Rules
- Port 5432 (PostgreSQL): To any (source RDS in different account)
- Port 5439 (Redshift): To Redshift security group
- Port 443 (HTTPS): To any (AWS API endpoints)

# Ingress Rules
- None (DMS initiates all connections)
```

**Redshift Security Group Rules**:
```hcl
# Ingress Rules
- Port 5439: From DMS security group
- Port 5439: From allowed CIDR blocks (optional)

# Egress Rules
- All traffic: To any (for maintenance and updates)
```

**Security Best Practices**:
- ✅ Use security group references instead of CIDR blocks
- ✅ Minimize ingress rules
- ✅ Document the purpose of each rule
- ✅ Regularly review and audit rules
- ✅ Use descriptive names and descriptions

### Network Access Control Lists (NACLs)

While not implemented by default, you can add NACLs for additional security:

```hcl
# Example NACL for private subnets
resource "aws_network_acl" "private" {
  vpc_id = aws_vpc.target.id
  subnet_ids = aws_subnet.target_private[*].id

  # Allow inbound from VPC
  ingress {
    rule_no    = 100
    protocol   = -1
    action     = "allow"
    cidr_block = var.target_vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Allow outbound
  egress {
    rule_no    = 100
    protocol   = -1
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
}
```

### VPC Endpoints (Optional Enhancement)

For improved security and cost savings:

```hcl
# S3 VPC Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.target.id
  service_name = "com.amazonaws.${var.target_region}.s3"
  
  route_table_ids = aws_route_table.target_private[*].id
}

# DMS VPC Endpoint
resource "aws_vpc_endpoint" "dms" {
  vpc_id            = aws_vpc.target.id
  service_name      = "com.amazonaws.${var.target_region}.dms"
  vpc_endpoint_type = "Interface"
  
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  subnet_ids         = aws_subnet.target_private[*].id
}
```

## IAM Security

### Service Roles

#### DMS VPC Role

**Purpose**: Allows DMS to manage VPC networking resources

**Trust Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "dms.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Attached Policies**:
- `AmazonDMSVPCManagementRole` (AWS managed)

#### DMS CloudWatch Logs Role

**Purpose**: Allows DMS to write logs to CloudWatch

**Trust Policy**: Same as DMS VPC Role

**Attached Policies**:
- `AmazonDMSCloudWatchLogsRole` (AWS managed)

#### DMS Redshift S3 Role

**Purpose**: Allows DMS to write data to S3 for Redshift loading

**Trust Policy**: Same as DMS VPC Role

**Permissions**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::bucket-name",
        "arn:aws:s3:::bucket-name/*"
      ]
    }
  ]
}
```

#### Redshift S3 Role

**Purpose**: Allows Redshift to read data from S3 using COPY command

**Trust Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "redshift.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Permissions**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::bucket-name",
        "arn:aws:s3:::bucket-name/*"
      ]
    }
  ]
}
```

### Cross-Account Access

#### Source Account Configuration

**IAM Role in Source Account**:
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
          "sts:ExternalId": "unique-external-id"
        }
      }
    }
  ]
}
```

**Permissions Required**:
```json
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
```

#### Security Best Practices for Cross-Account Access

1. **Use External ID**: Add an external ID to prevent the confused deputy problem
2. **Limit Account Access**: Specify exact account ARNs
3. **Use Conditions**: Add condition keys for additional security
4. **Audit Access**: Enable CloudTrail in both accounts
5. **Rotate Credentials**: Regular rotation of any credentials

### IAM Best Practices

- ✅ Use IAM roles instead of IAM users for services
- ✅ Enable MFA for human users
- ✅ Use AWS Organizations SCPs for guardrails
- ✅ Implement least privilege access
- ✅ Regular access reviews and audits
- ✅ Use IAM Access Analyzer
- ✅ Tag all IAM roles for cost allocation
- ✅ Document all custom policies

## Encryption

### Data at Rest

#### KMS Key Management

**DMS KMS Key**:
- Purpose: Encrypt DMS replication instance storage
- Key Rotation: Enabled (automatic annual rotation)
- Key Policy: Allows DMS service and account root
- Alias: `alias/dms-migration-dev-dms`

**Redshift KMS Key**:
- Purpose: Encrypt Redshift cluster storage and snapshots
- Key Rotation: Enabled (automatic annual rotation)
- Key Policy: Allows Redshift service and account root
- Alias: `alias/dms-migration-dev-redshift`

**KMS Key Policy Example**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT_ID:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "Allow service to use the key",
      "Effect": "Allow",
      "Principal": {
        "Service": "dms.amazonaws.com"
      },
      "Action": [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:CreateGrant",
        "kms:DescribeKey"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "dms.eu-west-1.amazonaws.com"
        }
      }
    }
  ]
}
```

#### S3 Bucket Encryption

**Server-Side Encryption**:
- Algorithm: AES-256 (S3-managed keys)
- Enforcement: Bucket policy denies unencrypted uploads
- Versioning: Enabled for data recovery

**Bucket Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyUnencryptedObjectUploads",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::bucket-name/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "AES256"
        }
      }
    }
  ]
}
```

#### Database Encryption

**PostgreSQL (Source)**:
- RDS Encryption: Enabled at rest
- SSL/TLS: Required for connections
- Parameter Group: `rds.force_ssl = 1`

**Redshift (Target)**:
- Cluster Encryption: KMS encrypted
- Snapshots: Automatically encrypted
- SSL/TLS: Required for connections

### Data in Transit

#### TLS/SSL Configuration

**DMS Endpoints**:
```hcl
# Source endpoint
resource "aws_dms_endpoint" "source" {
  ssl_mode = "require"  # Options: none, require, verify-ca, verify-full
  
  # For verify-ca or verify-full
  certificate_arn = aws_dms_certificate.source.certificate_arn
}

# Target endpoint
resource "aws_dms_endpoint" "target" {
  ssl_mode = "require"
}
```

**Redshift Connections**:
```sql
-- Enforce SSL in Redshift
ALTER USER admin CONNECTION_LIMIT 100 SSL REQUIRED;
```

**Certificate Management**:
```bash
# Import certificate to DMS
aws dms import-certificate \
  --certificate-identifier my-cert \
  --certificate-pem file://cert.pem \
  --certificate-wallet file://wallet.p12
```

## Secrets Management

### Current Implementation

Sensitive data is passed via Terraform variables:
- Database passwords
- Usernames
- Connection strings

### Recommended Enhancement: AWS Secrets Manager

**Create Secrets**:
```hcl
# Source RDS credentials
resource "aws_secretsmanager_secret" "source_rds" {
  name        = "${var.project_name}-${var.environment}-source-rds-credentials"
  description = "Credentials for source RDS PostgreSQL"
  
  kms_key_id = aws_kms_key.secrets.id
}

resource "aws_secretsmanager_secret_version" "source_rds" {
  secret_id = aws_secretsmanager_secret.source_rds.id
  
  secret_string = jsonencode({
    username = var.source_rds_username
    password = var.source_rds_password
    endpoint = var.source_rds_endpoint
    port     = var.source_rds_port
    database = var.source_rds_database_name
  })
}

# Redshift credentials
resource "aws_secretsmanager_secret" "redshift" {
  name        = "${var.project_name}-${var.environment}-redshift-credentials"
  description = "Credentials for Redshift cluster"
  
  kms_key_id = aws_kms_key.secrets.id
}
```

**Use in DMS**:
```hcl
data "aws_secretsmanager_secret_version" "source_rds" {
  secret_id = aws_secretsmanager_secret.source_rds.id
}

locals {
  source_rds_creds = jsondecode(data.aws_secretsmanager_secret_version.source_rds.secret_string)
}

resource "aws_dms_endpoint" "source" {
  username = local.source_rds_creds.username
  password = local.source_rds_creds.password
  # ...
}
```

**Rotation Configuration**:
```hcl
resource "aws_secretsmanager_secret_rotation" "source_rds" {
  secret_id           = aws_secretsmanager_secret.source_rds.id
  rotation_lambda_arn = aws_lambda_function.rotate_secret.arn
  
  rotation_rules {
    automatically_after_days = 30
  }
}
```

## Compliance and Auditing

### CloudTrail

**Enable CloudTrail in Both Accounts**:
```hcl
resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-${var.environment}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
  
  event_selector {
    read_write_type           = "All"
    include_management_events = true
    
    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::${aws_s3_bucket.dms_intermediate.id}/*"]
    }
  }
}
```

### VPC Flow Logs

**Enable for Network Analysis**:
```hcl
resource "aws_flow_log" "target_vpc" {
  vpc_id          = aws_vpc.target.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
}
```

### AWS Config

**Track Configuration Changes**:
```hcl
resource "aws_config_configuration_recorder" "main" {
  name     = "${var.project_name}-${var.environment}-config-recorder"
  role_arn = aws_iam_role.config.arn
  
  recording_group {
    all_supported = true
  }
}
```

### GuardDuty

**Enable Threat Detection**:
```bash
aws guardduty create-detector --enable --region eu-west-1
```

## Security Monitoring

### CloudWatch Alarms

**Security-Related Alarms**:

```hcl
# Unauthorized API calls
resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  alarm_name          = "unauthorized-api-calls"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnauthorizedAPICalls"
  namespace           = "CloudTrailMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alert on unauthorized API calls"
}

# Root account usage
resource "aws_cloudwatch_metric_alarm" "root_usage" {
  alarm_name          = "root-account-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RootAccountUsage"
  namespace           = "CloudTrailMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert on root account usage"
}
```

### Security Metrics

**Key Metrics to Monitor**:
- Failed authentication attempts
- Privilege escalation attempts
- Security group changes
- IAM policy changes
- Encryption key usage
- Cross-account access patterns

## Data Protection

### Data Classification

**Sensitivity Levels**:
- **Public**: Can be freely shared
- **Internal**: Within organization only
- **Confidential**: Restricted access
- **Restricted**: Highest security level

**Handling Requirements**:
- Confidential and Restricted data must be encrypted
- Access logging required for all data access
- Data retention policies enforced
- Regular access reviews

### Data Lifecycle

**Stages**:
1. **Creation**: Data encrypted at creation
2. **Processing**: Data encrypted during migration
3. **Storage**: Data encrypted at rest in Redshift
4. **Archival**: Automated snapshots with encryption
5. **Deletion**: Secure deletion of expired data

### Backup and Recovery

**Backup Strategy**:
- Automated daily Redshift snapshots (7-day retention)
- Manual snapshots before major changes
- S3 versioning for intermediate data
- Cross-region backup copies (optional)

**Recovery Procedures**:
- Documented recovery time objectives (RTO)
- Regular disaster recovery testing
- Automated recovery procedures
- Incident response playbooks

## Incident Response

### Security Incident Procedures

**Detection**:
1. CloudWatch alarms trigger
2. GuardDuty findings
3. Manual reporting
4. Log analysis

**Response**:
1. Isolate affected resources
2. Preserve evidence (snapshots, logs)
3. Assess impact and scope
4. Contain and eradicate threat
5. Recover systems
6. Post-incident analysis

**Communication**:
- Incident commander assignment
- Stakeholder notifications
- Compliance reporting (if required)
- Post-mortem documentation

### Common Security Scenarios

**Scenario 1: Compromised Credentials**
1. Rotate all affected credentials immediately
2. Review CloudTrail for unauthorized access
3. Revoke sessions for compromised users
4. Update IAM policies if needed
5. Enable MFA if not already enabled

**Scenario 2: Unauthorized Access Attempt**
1. Review security group rules
2. Check for new IAM users/roles
3. Analyze VPC Flow Logs
4. Verify GuardDuty findings
5. Implement additional controls

**Scenario 3: Data Exfiltration Detected**
1. Block outbound traffic immediately
2. Review S3 access logs
3. Check Redshift query logs
4. Identify affected data
5. Notify stakeholders per compliance requirements

## Security Checklist

### Deployment Security

- [ ] Review all IAM policies for least privilege
- [ ] Verify encryption enabled for all data stores
- [ ] Confirm SSL/TLS enforced for all connections
- [ ] Check security group rules are minimal
- [ ] Enable CloudTrail in all accounts
- [ ] Configure CloudWatch alarms
- [ ] Review KMS key policies
- [ ] Verify S3 bucket policies block public access
- [ ] Test cross-account access restrictions
- [ ] Document all security configurations

### Operational Security

- [ ] Regular access reviews (monthly)
- [ ] Credential rotation (quarterly)
- [ ] Security patching (automated)
- [ ] Log retention compliance
- [ ] Backup testing (monthly)
- [ ] Disaster recovery drills (quarterly)
- [ ] Security training for team
- [ ] Vulnerability assessments
- [ ] Penetration testing (annual)
- [ ] Compliance audits

## References

- [AWS Security Best Practices](https://aws.amazon.com/security/best-practices/)
- [AWS DMS Security](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Security.html)
- [Amazon Redshift Security](https://docs.aws.amazon.com/redshift/latest/mgmt/security.html)
- [AWS KMS Best Practices](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
