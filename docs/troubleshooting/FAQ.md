# Frequently Asked Questions (FAQ)

## General Questions

### Q: What is AWS DMS?
**A:** AWS Database Migration Service (DMS) is a cloud service that makes it easy to migrate relational databases, data warehouses, NoSQL databases, and other types of data stores. You can use AWS DMS to migrate your data into the AWS Cloud or between combinations of cloud and on-premises setups.

### Q: Why use cross-account migration?
**A:** Cross-account migration provides:
- Better security isolation
- Separate billing and cost management
- Compliance with organizational policies
- Clear separation of development/production environments

### Q: What is the difference between full-load and CDC?
**A:** 
- **Full Load**: One-time migration of existing data
- **CDC (Change Data Capture)**: Continuous replication of ongoing changes
- **Full Load and CDC**: Combines both - initial full load followed by ongoing CDC

## Setup and Configuration

### Q: How do I configure cross-account access?
**A:** 
1. Create IAM roles in both accounts
2. Configure trust relationships
3. Grant necessary permissions
4. Use role assumption in your code/Terraform

See the IAM module in `terraform/modules/iam/` for examples.

### Q: What are the minimum required permissions?
**A:**
- DMS: Create/manage replication instances, endpoints, tasks
- EC2: Manage VPC, subnets, security groups
- RDS: Describe instances
- Redshift: Describe clusters
- S3: Read/write to DMS bucket
- IAM: Assume cross-account roles

### Q: How do I handle database credentials securely?
**A:** 
1. Use AWS Secrets Manager (recommended)
2. Use environment variables (not for production)
3. Use Terraform variables with encryption
4. Never commit credentials to Git

## Migration Issues

### Q: My migration task is failing with "Connection timeout"
**A:** 
1. Check security group rules
2. Verify network ACLs
3. Ensure correct VPC peering/routing
4. Test database connectivity manually
5. Check if endpoints are in correct subnets

### Q: The replication lag is too high. How can I reduce it?
**A:**
1. Increase DMS instance size
2. Enable parallel apply threads
3. Optimize target database (distribution keys, sort keys)
4. Reduce transformation complexity
5. Check network bandwidth

### Q: Some tables failed to migrate. What should I do?
**A:**
1. Check CloudWatch logs for specific errors
2. Verify table structures are compatible
3. Check for data type compatibility issues
4. Review LOB settings if tables have large objects
5. Examine error table in DMS control schema

### Q: How do I handle schema differences?
**A:** Use transformation rules in table mappings:
1. Rename schemas
2. Rename tables/columns
3. Add/remove columns
4. Transform data types

## Performance

### Q: How can I improve migration performance?
**A:**
1. Use larger DMS instance class
2. Enable parallel load for large tables
3. Adjust `MaxFullLoadSubTasks`
4. Use batch apply mode
5. Partition large tables
6. Optimize source database (disable triggers, constraints temporarily)

### Q: What DMS instance size should I use?
**A:** Depends on:
- Data volume
- Number of tables
- Network throughput
- Required migration speed

Start with `dms.t3.medium` for testing, scale up to `dms.c5.xlarge` or larger for production.

### Q: Can I migrate multiple databases simultaneously?
**A:** Yes, you can:
1. Use multiple replication tasks on one instance
2. Use separate DMS instances for each database
3. Prioritize critical databases

## Validation and Testing

### Q: How do I validate data after migration?
**A:** Use the provided Python validators:
```python
from validators import DataValidator
validator = DataValidator(source_config, target_config)
results = validator.validate_row_counts(tables)
```

Also use:
1. Row count comparisons
2. Checksum validation
3. Statistical comparisons
4. Sample data verification

### Q: Should I enable DMS validation?
**A:** 
- **Yes** for critical data
- Adds some overhead (10-20%)
- Provides detailed validation reports
- Can be enabled during full-load-and-cdc

### Q: How do I test the migration before production?
**A:**
1. Use dev/staging environments
2. Test with sample data first
3. Perform dry runs
4. Validate thoroughly
5. Document rollback procedures

## Cost and Optimization

### Q: How much does DMS cost?
**A:** Costs include:
- DMS replication instance (hourly)
- Data transfer (cross-region charges)
- Storage for replication instance
- CloudWatch logs storage
- S3 storage for intermediate files

Use AWS Cost Calculator for estimates.

### Q: How can I reduce migration costs?
**A:**
1. Right-size DMS instances
2. Use compression
3. Optimize migration schedule (off-peak hours)
4. Delete old logs and snapshots
5. Stop instances when not in use (dev/test)

## Troubleshooting

### Q: Where can I find DMS logs?
**A:** 
1. CloudWatch Logs: `/aws/dms/tasks/{task-id}`
2. DMS Console: Task monitoring tab
3. Task error tables in target database

### Q: Common error: "Insufficient privileges"
**A:**
1. Check database user permissions
2. For PostgreSQL: Grant `rds_superuser` role
3. For Redshift: Ensure user has proper permissions
4. Review IAM role policies

### Q: How do I handle LOB (Large Objects)?
**A:**
- Set `LimitedSizeLobMode`: true
- Configure `LobMaxSize` appropriately
- Consider inline LOBs for small objects
- Use full LOB mode only when necessary

### Q: Task stuck in "Starting" state
**A:**
1. Check CloudWatch logs
2. Verify endpoints are accessible
3. Ensure replication instance is available
4. Check for resource constraints
5. Try stopping and restarting the task

## Monitoring and Maintenance

### Q: What metrics should I monitor?
**A:** Key metrics:
- `FullLoadThroughputRowsSource`
- `CDCLatencySource`
- `NetworkTransmitThroughput`
- `CPUUtilization`
- `FreeableMemory`

### Q: How do I set up alerts?
**A:** Use the monitoring module or CloudWatch alarms:
```bash
terraform apply -target=module.monitoring
```

Configure SNS notifications for critical events.

### Q: How often should I review logs?
**A:**
- During migration: Real-time monitoring
- After cutover: Daily for 1 week
- Steady state: Weekly reviews
- Set up automated alerts for errors

## Advanced Topics

### Q: Can I use multiple target endpoints?
**A:** Yes, you can configure multiple tasks to load into different targets.

### Q: How do I handle DDL changes during migration?
**A:** 
1. Configure `ChangeProcessingDdlHandlingPolicy`
2. Options: Drop, Truncate, Alter
3. Test DDL changes in non-production first

### Q: Can I resume a failed migration?
**A:** Yes:
```python
dms.start_replication_task(task_arn, start_type='resume-processing')
```

### Q: How do I implement custom transformations?
**A:** Use table mapping transformation rules or implement in target database triggers.

## Getting Help

### Q: Where can I get more help?
**A:**
1. Check documentation in `docs/`
2. Review AWS DMS documentation
3. Post issues on GitHub
4. Contact AWS Support (for AWS-specific issues)
5. Review CloudWatch logs for detailed errors

### Q: How do I report bugs?
**A:** 
1. Create GitHub issue with:
   - Clear description
   - Steps to reproduce
   - Logs and error messages
   - Environment details
2. Use issue templates provided
