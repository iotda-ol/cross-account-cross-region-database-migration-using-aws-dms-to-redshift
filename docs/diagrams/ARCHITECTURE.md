# Architecture Overview

## High-Level Architecture

This solution implements a cross-account, cross-region database migration from Amazon RDS PostgreSQL to Amazon Redshift using AWS Database Migration Service (DMS).

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Source Account (us-east-1)                         │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                            Source VPC                                 │  │
│  │  ┌─────────────────┐         ┌──────────────────┐                   │  │
│  │  │  Private Subnet │         │  Database Subnet │                   │  │
│  │  │                 │         │                  │                   │  │
│  │  │                 │         │  ┌────────────┐  │                   │  │
│  │  │                 │         │  │    RDS     │  │                   │  │
│  │  │                 │         │  │ PostgreSQL │  │                   │  │
│  │  │                 │         │  │  (Source)  │  │                   │  │
│  │  │                 │         │  └─────┬──────┘  │                   │  │
│  │  └─────────────────┘         └────────┼─────────┘                   │  │
│  └──────────────────────────────────────┼──────────────────────────────┘  │
│                                          │                                  │
│                                          │ VPC Peering                      │
└──────────────────────────────────────────┼──────────────────────────────────┘
                                           │
┌──────────────────────────────────────────┼──────────────────────────────────┐
│                          Target Account (us-west-2)                         │
│  ┌───────────────────────────────────────┼──────────────────────────────┐  │
│  │                       Target VPC      │                              │  │
│  │  ┌─────────────────┐  ┌───────────────▼──────┐  ┌─────────────────┐ │  │
│  │  │  Public Subnet  │  │  Private Subnet      │  │ Database Subnet │ │  │
│  │  │                 │  │                      │  │                 │ │  │
│  │  │  ┌───────────┐  │  │  ┌────────────────┐ │  │ ┌─────────────┐ │ │  │
│  │  │  │    NAT    │  │  │  │      DMS       │ │  │ │  Redshift   │ │ │  │
│  │  │  │  Gateway  │  │  │  │  Replication   │ │  │ │   Cluster   │ │ │  │
│  │  │  └───────────┘  │  │  │    Instance    │ │  │ │  (Target)   │ │ │  │
│  │  │                 │  │  └────────┬───────┘ │  │ └──────▲──────┘ │ │  │
│  │  └─────────────────┘  └───────────┼─────────┘  └────────┼────────┘ │  │
│  │                                    │                     │          │  │
│  │                                    └─────────────────────┘          │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────┐  ┌──────────────┐  ┌────────────────┐                 │
│  │  S3 Bucket    │  │  CloudWatch  │  │  IAM Roles     │                 │
│  │  (DMS Tasks)  │  │  Monitoring  │  │  & Policies    │                 │
│  └───────────────┘  └──────────────┘  └────────────────┘                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Components

### Source Account Components

1. **VPC**: Isolated network for source database
2. **RDS PostgreSQL**: Source database with logical replication enabled
3. **Security Groups**: Controlled access to database
4. **IAM Roles**: Cross-account access roles

### Target Account Components

1. **VPC**: Isolated network for DMS and target database
   - Public Subnets: NAT Gateway for internet access
   - Private Subnets: DMS replication instance
   - Database Subnets: Redshift cluster

2. **DMS Replication Instance**: Handles data migration
   - Connects to source via VPC peering
   - Loads data to target Redshift
   - Supports full-load and CDC

3. **Redshift Cluster**: Target data warehouse
   - Optimized for analytics
   - Column-oriented storage
   - MPP architecture

4. **S3 Bucket**: Intermediate storage for DMS
   - Error logs
   - Large object storage
   - Task artifacts

5. **CloudWatch**: Monitoring and logging
   - Task metrics
   - Performance monitoring
   - Alarm notifications

6. **IAM Roles & Policies**:
   - DMS VPC management role
   - CloudWatch logs role
   - S3 access role
   - Cross-account assume role

## Data Flow

1. **Initial Setup**:
   - Terraform provisions all infrastructure
   - IAM roles establish cross-account trust
   - VPC peering connects networks
   - Security groups allow required traffic

2. **Full Load Phase**:
   - DMS reads data from source RDS PostgreSQL
   - Data transferred over VPC peering
   - DMS transforms data as needed
   - Data loaded into Redshift tables
   - Progress tracked in CloudWatch

3. **CDC Phase** (if enabled):
   - DMS monitors PostgreSQL WAL logs
   - Captures ongoing changes
   - Replicates changes to Redshift
   - Maintains data consistency
   - Minimal replication lag

4. **Monitoring**:
   - CloudWatch collects metrics
   - Logs stored in CloudWatch Logs
   - Alarms trigger on errors
   - SNS notifications sent

## Network Architecture

### VPC Peering
- Establishes private connectivity between accounts
- No public internet exposure
- Low latency, high throughput
- Secure encrypted connection

### Security
- Security groups act as virtual firewalls
- Network ACLs provide subnet-level protection
- VPC Flow Logs capture network traffic
- All data encrypted in transit and at rest

## Scalability

### Horizontal Scaling
- Multiple DMS tasks for parallel migration
- Separate tasks for large tables
- Partition-based loading

### Vertical Scaling
- Larger DMS instance classes
- More Redshift nodes
- Increased storage capacity

## High Availability

### DMS
- Multi-AZ deployment option
- Automatic failover
- Backup replication instance

### Redshift
- Multi-node cluster
- Automated snapshots
- Cross-region snapshot copy

### RDS
- Multi-AZ deployment
- Automated backups
- Read replicas

## Security Architecture

### Encryption
- **At Rest**: AWS KMS encryption for RDS, Redshift, S3
- **In Transit**: SSL/TLS for all connections
- **Keys**: Customer-managed CMKs

### Access Control
- **IAM**: Least privilege principle
- **Security Groups**: Port-level restrictions
- **VPC**: Network isolation
- **Secrets Manager**: Credential storage

### Compliance
- VPC Flow Logs for audit
- CloudWatch Logs retention
- IAM access logging
- S3 bucket policies

## Disaster Recovery

### Backup Strategy
- RDS automated backups (7-35 days)
- Redshift automated snapshots (1-35 days)
- Manual snapshots before major changes
- Cross-region snapshot copy

### Recovery Procedures
1. Identify failure point
2. Restore from latest backup
3. Resume DMS task from checkpoint
4. Validate data integrity
5. Update DNS/endpoints

## Cost Optimization

### Right-Sizing
- Start with smaller instances
- Monitor usage metrics
- Scale based on actual needs

### Reserved Instances
- For long-running migrations
- Significant cost savings
- 1 or 3 year commitments

### Data Transfer
- Use VPC peering (cheaper than internet)
- Compress data when possible
- Schedule migrations off-peak

### Storage
- Lifecycle policies for S3
- Delete old snapshots
- Use appropriate storage classes

## Performance Optimization

### DMS Settings
- Parallel full load threads
- Batch apply mode
- LOB optimization
- Task tuning parameters

### Redshift Optimization
- Distribution keys
- Sort keys
- Compression encoding
- VACUUM and ANALYZE

### Network Optimization
- Enhanced networking
- Placement groups
- VPC endpoint for S3

## Monitoring Metrics

### Key Metrics
- `FullLoadThroughputRowsSource`: Source read rate
- `FullLoadThroughputRowsTarget`: Target write rate
- `CDCLatencySource`: Replication lag
- `CPUUtilization`: Resource usage
- `FreeableMemory`: Memory availability
- `NetworkTransmitThroughput`: Network performance

### Alarms
- Task failures
- High replication lag (> 5 minutes)
- High CPU (> 80%)
- Low memory (< 20%)
- Error count thresholds

## Best Practices

1. **Testing**: Always test in dev/staging first
2. **Validation**: Implement comprehensive data validation
3. **Monitoring**: Set up monitoring before migration
4. **Documentation**: Document all configurations
5. **Rollback**: Have rollback procedures ready
6. **Communication**: Keep stakeholders informed
7. **Security**: Follow least privilege principle
8. **Automation**: Use IaC for reproducibility

## Future Enhancements

- Multi-source migrations
- Additional database engines
- Enhanced monitoring dashboards
- Automated optimization
- Self-healing capabilities
- Cost analytics and recommendations
