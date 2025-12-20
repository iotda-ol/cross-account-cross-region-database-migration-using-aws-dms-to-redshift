# Architecture Documentation

## Overview

This document provides detailed architectural decisions and rationale for the cross-account, cross-region database migration solution using AWS DMS.

## Architecture Principles

### 1. Security First
- All data encrypted at rest and in transit
- Least privilege IAM policies
- Network isolation using private subnets
- No direct internet exposure for databases

### 2. High Availability
- Multi-AZ deployment capability
- NAT Gateways in each availability zone
- Automated failover for DMS (when Multi-AZ enabled)
- Redshift automated snapshots

### 3. Scalability
- Horizontal scaling for Redshift (add nodes)
- Vertical scaling for DMS instance
- Auto-scaling capabilities for future enhancement

### 4. Observability
- CloudWatch metrics for all components
- Automated alarms for critical metrics
- Centralized logging
- Performance monitoring

### 5. Cost Optimization
- Right-sized instances for workload
- Lifecycle policies for S3 storage
- Resource tagging for cost allocation
- Development vs production configurations

## Component Architecture

### Network Architecture

#### VPC Design
```
10.0.0.0/16 (Target VPC)
├── Public Subnets (NAT Gateways, Egress)
│   ├── 10.0.101.0/24 (eu-west-1a)
│   ├── 10.0.102.0/24 (eu-west-1b)
│   └── 10.0.103.0/24 (eu-west-1c)
└── Private Subnets (DMS, Redshift)
    ├── 10.0.1.0/24 (eu-west-1a)
    ├── 10.0.2.0/24 (eu-west-1b)
    └── 10.0.3.0/24 (eu-west-1c)
```

**Rationale**:
- Private subnets isolate database resources from internet
- Public subnets provide controlled internet egress via NAT
- Three AZs provide high availability
- /24 subnets provide sufficient IP address space

#### Security Groups

**DMS Security Group**:
- Egress to RDS PostgreSQL (port 5432)
- Egress to Redshift (port 5439)
- Egress to HTTPS (port 443) for AWS API calls
- No ingress rules (DMS initiates all connections)

**Redshift Security Group**:
- Ingress from DMS security group (port 5439)
- Optional ingress from specific CIDR blocks
- All egress allowed

**Rationale**:
- Implements least privilege network access
- Prevents unauthorized access
- Allows only necessary communication paths

### Data Flow Architecture

#### Migration Phases

**Phase 1: Full Load**
```
Source RDS → DMS Replication Instance → S3 Intermediate → Redshift (COPY)
```

**Phase 2: Change Data Capture (CDC)**
```
Source RDS WAL → DMS (Logical Replication) → S3 → Redshift (Incremental Load)
```

**Rationale**:
- Full load ensures all existing data is migrated
- CDC captures ongoing changes with minimal latency
- S3 intermediate storage provides staging and recovery
- COPY command is optimized for Redshift bulk loading

### IAM Architecture

#### Service Roles

**dms-vpc-role**: 
- Purpose: Allows DMS to manage VPC networking
- Permissions: AmazonDMSVPCManagementRole
- Trust: dms.amazonaws.com

**dms-cloudwatch-logs-role**:
- Purpose: Allows DMS to write logs to CloudWatch
- Permissions: AmazonDMSCloudWatchLogsRole
- Trust: dms.amazonaws.com

**dms-redshift-s3-role**:
- Purpose: Allows DMS to write to S3 intermediate storage
- Permissions: Custom policy for S3 bucket access
- Trust: dms.amazonaws.com

**redshift-s3-role**:
- Purpose: Allows Redshift to read from S3 for COPY
- Permissions: Custom policy for S3 bucket access
- Trust: redshift.amazonaws.com

**cross-account-dms-role**:
- Purpose: Enables cross-account access from target to source
- Permissions: EC2 describe operations for networking
- Trust: Both DMS service and target account root

**Rationale**:
- Separation of concerns with dedicated roles
- Principle of least privilege
- Enables audit trail for each service action
- Supports cross-account access securely

### Encryption Architecture

#### Encryption at Rest

**DMS Replication Instance**:
- KMS key: `dms-migration-dev-dms-kms-key`
- Purpose: Encrypt replication instance storage
- Key rotation: Enabled

**Redshift Cluster**:
- KMS key: `dms-migration-dev-redshift-kms-key`
- Purpose: Encrypt cluster storage and snapshots
- Key rotation: Enabled

**S3 Buckets**:
- Encryption: AES-256 (S3-managed)
- Purpose: Encrypt intermediate data and logs
- Bucket policies: Enforce encryption

**Rationale**:
- Separate KMS keys per service for key isolation
- Automatic key rotation for security
- Compliance with data protection regulations
- Defense in depth approach

#### Encryption in Transit

**DMS Connections**:
- Source endpoint: SSL/TLS required
- Target endpoint: SSL/TLS required

**Redshift Connections**:
- Client connections: SSL/TLS enforced

**Rationale**:
- Protects data during network transmission
- Prevents man-in-the-middle attacks
- Meets compliance requirements

### Storage Architecture

#### S3 Buckets

**dms-intermediate-storage**:
- Purpose: Staging area for data being loaded to Redshift
- Versioning: Enabled
- Lifecycle: Data deleted after successful load
- Access: DMS write, Redshift read

**redshift-logs**:
- Purpose: Store Redshift audit and query logs
- Versioning: Enabled
- Lifecycle: 90-day retention, then delete
- Access: Redshift write-only

**Rationale**:
- Separate buckets for different purposes
- Versioning enables recovery from errors
- Lifecycle policies control costs
- Bucket policies enforce security

### Monitoring Architecture

#### CloudWatch Metrics

**DMS Metrics**:
- CPUUtilization (threshold: 80%)
- FreeableMemory (threshold: 1 GB)
- FreeStorageSpace (threshold: 10 GB)

**Redshift Metrics**:
- CPUUtilization (threshold: 80%)
- PercentageDiskSpaceUsed (threshold: 85%)
- HealthStatus (threshold: < 1)

**Rationale**:
- Proactive alerting prevents issues
- Resource utilization tracking enables optimization
- Health checks ensure availability

#### CloudWatch Logs

**DMS Logs**:
- Log group: `/aws/dms/dms-migration-dev`
- Retention: 7 days
- Components: SOURCE_CAPTURE, TARGET_APPLY, TASK_MANAGER

**Rationale**:
- Centralized logging for troubleshooting
- Retention policy balances cost and compliance
- Component-level logs enable detailed debugging

## Design Decisions

### Why eu-west-1 for Target Region?

**Decision**: Deploy target infrastructure in eu-west-1

**Rationale**:
- GDPR compliance requirements (data residency)
- Lower latency for European users
- Cost optimization (data egress charges)
- Regional service availability

### Why Redshift Over Other Data Warehouses?

**Decision**: Use Amazon Redshift as target data warehouse

**Rationale**:
- Native AWS service integration
- Columnar storage optimized for analytics
- Mature ecosystem and tooling
- Cost-effective for large datasets
- DMS native support with optimized loading

**Alternatives Considered**:
- Amazon Aurora: Not optimized for analytics workloads
- Amazon Athena: Requires different architecture (serverless)
- Snowflake: Additional vendor dependency

### Why Multi-AZ NAT Gateways?

**Decision**: Deploy NAT Gateway in each availability zone

**Rationale**:
- Eliminates single point of failure
- Reduces cross-AZ data transfer costs
- Improves availability during AZ failures
- Better network performance

**Trade-offs**:
- Higher cost (~$100/month vs ~$33/month)
- More complex routing configuration
- Justified for production workloads

### Why Separate KMS Keys?

**Decision**: Use separate KMS keys for DMS and Redshift

**Rationale**:
- Key isolation (compromise of one doesn't affect other)
- Service-specific key policies
- Compliance requirement separation
- Easier key rotation management

**Trade-offs**:
- Slightly more complex configuration
- Minimal cost impact ($1/month per key)

### Why pglogical Plugin?

**Decision**: Use pglogical plugin for PostgreSQL logical replication

**Rationale**:
- Mature and stable plugin
- Efficient CDC with minimal overhead
- Supports all PostgreSQL data types
- Better than test_decoding for production

**Alternatives Considered**:
- test_decoding: Less efficient, development use
- wal2json: Additional extension installation required

### Why S3 Intermediate Storage?

**Decision**: Use S3 as intermediate storage for Redshift loads

**Rationale**:
- Decouples DMS from Redshift
- Enables retry on failure
- Better performance for large batches
- Standard Redshift COPY pattern
- Cost-effective staging area

**Trade-offs**:
- Additional storage costs (minimal)
- Slightly more complex architecture
- Industry best practice

## Scalability Considerations

### Vertical Scaling

**DMS Replication Instance**:
- Current: dms.t3.medium
- Scale to: dms.c5.2xlarge or dms.c5.4xlarge
- Triggers: High CPU, low memory, throughput requirements

**Redshift Cluster**:
- Current: 2x dc2.large
- Scale to: dc2.8xlarge or ra3.4xlarge nodes
- Triggers: Query performance, concurrent user load

### Horizontal Scaling

**Redshift Cluster**:
- Add nodes: Scale from 2 to 4, 8, or more nodes
- Redistribution: Automatic during resize
- Downtime: Elastic resize (minutes) vs classic (hours)

### Performance Optimization

**DMS Settings**:
- MaxFullLoadSubTasks: 8 (parallel table loads)
- CommitRate: 10000 (batch commit size)
- ChangeProcessingTuning: Adjust based on workload

**Redshift Settings**:
- Distribution keys: Optimize for join patterns
- Sort keys: Optimize for query filters
- Compression: Automatic encoding optimization
- WLM: Configure query queues

## High Availability

### Component Availability

| Component | Availability | Recovery |
|-----------|--------------|----------|
| DMS Instance | Single-AZ (Multi-AZ optional) | Manual restart |
| Redshift | Single-AZ with snapshots | Restore from snapshot |
| NAT Gateway | Per-AZ redundancy | Automatic failover |
| S3 | 99.99% durability | Automatic |

### Disaster Recovery

**RTO (Recovery Time Objective)**: 4 hours
**RPO (Recovery Point Objective)**: 5 minutes (CDC lag)

**Backup Strategy**:
1. Redshift automated snapshots (daily)
2. Manual snapshots before major changes
3. Cross-region snapshot copy (optional)
4. S3 versioning for data recovery

**Recovery Procedures**:
1. Restore Redshift from snapshot
2. Recreate DMS instance (Terraform)
3. Resume replication from last checkpoint
4. Validate data consistency

## Security Architecture

### Defense in Depth

**Layer 1: Network**
- VPC isolation
- Private subnets
- Security groups
- NACLs (optional)

**Layer 2: Access Control**
- IAM roles and policies
- Cross-account trust policies
- Service control policies (optional)

**Layer 3: Encryption**
- KMS encryption at rest
- SSL/TLS in transit
- Key rotation

**Layer 4: Monitoring**
- CloudWatch alarms
- CloudTrail audit logs
- VPC Flow Logs (optional)
- GuardDuty (optional)

### Compliance

**GDPR Considerations**:
- Data residency (eu-west-1)
- Encryption requirements
- Access logging
- Data retention policies

**Best Practices**:
- Regular security assessments
- Automated compliance checks
- Incident response procedures
- Security training

## Cost Architecture

### Monthly Cost Breakdown (Production)

```
Fixed Costs:
- DMS Instance (dms.t3.medium):        $140
- Redshift Cluster (2x dc2.large):     $480
- NAT Gateways (3x):                   $100
- KMS Keys (2x):                       $2
                                       ----
Subtotal:                              $722

Variable Costs:
- S3 Storage (100 GB):                 $2
- Data Transfer (1 TB):                $90
- CloudWatch Logs:                     $5
                                       ----
Subtotal:                              $97

Total Monthly Cost:                    $819
```

### Cost Optimization Opportunities

1. **Reserved Instances**:
   - 1-year Redshift RI: 35% savings
   - 3-year Redshift RI: 55% savings

2. **Spot Instances** (non-production):
   - EC2 with DMS software: 70% savings

3. **Schedule Resources**:
   - Stop DMS when not replicating: 50% savings
   - Pause Redshift in dev: 100% savings

4. **Data Transfer Optimization**:
   - VPC endpoints: Free data transfer
   - Compression: Reduce transfer volume

## Future Enhancements

### Planned Improvements

1. **Automation**:
   - Lambda functions for task management
   - EventBridge rules for automated actions
   - Step Functions for orchestration

2. **Monitoring**:
   - Custom CloudWatch dashboards
   - SNS notifications for alarms
   - Integration with monitoring tools

3. **Security**:
   - AWS Secrets Manager for credentials
   - WAF for API protection
   - Enhanced monitoring with GuardDuty

4. **Performance**:
   - Redshift Spectrum for S3 queries
   - Materialized views for common queries
   - Concurrency scaling for Redshift

## Conclusion

This architecture provides a secure, scalable, and cost-effective solution for cross-account, cross-region database migration. The design follows AWS best practices and DEA-C01 certification guidelines while maintaining flexibility for future enhancements.
