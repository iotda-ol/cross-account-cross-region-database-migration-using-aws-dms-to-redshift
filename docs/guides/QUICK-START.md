# Quick Start Guide

Get up and running with DMS migration in 15 minutes!

## Prerequisites Checklist

- [ ] Two AWS accounts (source and target)
- [ ] AWS CLI configured
- [ ] Terraform 1.0+ installed
- [ ] Python 3.9+ installed
- [ ] Git installed

## Step 1: Clone Repository (1 min)

```bash
git clone https://github.com/iotda-ol/cross-account-cross-region-database-migration-using-aws-dms-to-redshift.git
cd cross-account-cross-region-database-migration-using-aws-dms-to-redshift
```

## Step 2: Set Up Python Environment (2 min)

```bash
cd python/
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
cd ..
```

## Step 3: Configure AWS Credentials (2 min)

```bash
# Configure source account
aws configure --profile source-account
# Enter Access Key ID, Secret Key, Region, Output format

# Configure target account
aws configure --profile target-account
# Enter Access Key ID, Secret Key, Region, Output format
```

## Step 4: Configure Terraform Variables (3 min)

```bash
cd terraform/environments/dev/
cp ../../../config/examples/terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and update these values:

```hcl
# Required changes
source_account_id = "123456789012"  # Your source account ID
target_account_id = "098765432109"  # Your target account ID

# Database credentials (change these!)
rds_password          = "YourStrongPassword123!"
redshift_master_password = "YourStrongPassword123!"

# Optional: Adjust instance sizes for cost
rds_instance_class    = "db.t3.small"      # Smaller for testing
dms_instance_class    = "dms.t3.small"     # Smaller for testing
redshift_node_type    = "dc2.large"        # Smallest Redshift
```

## Step 5: Initialize Terraform (1 min)

```bash
terraform init
```

## Step 6: Deploy Infrastructure (5 min)

```bash
# Review what will be created
terraform plan

# Deploy (this takes ~5-10 minutes)
terraform apply
```

Type `yes` when prompted.

## Step 7: Verify Deployment (1 min)

```bash
# Check outputs
terraform output

# You should see:
# - vpc_id
# - rds_endpoint
# - redshift_endpoint
# - dms_replication_instance_arn
```

## What's Next?

### Create DMS Endpoints and Tasks

1. **Create Source Endpoint**:
   ```python
   from dms_manager import DMSManager
   
   dms = DMSManager(region_name='us-west-2')
   source_endpoint = dms.create_endpoint(
       endpoint_identifier='source-postgres',
       endpoint_type='source',
       engine_name='postgres',
       server_name='your-rds-endpoint',
       port=5432,
       database_name='sourcedb',
       username='postgres',
       password='your-password'
   )
   ```

2. **Create Target Endpoint**:
   ```python
   target_endpoint = dms.create_endpoint(
       endpoint_identifier='target-redshift',
       endpoint_type='target',
       engine_name='redshift',
       server_name='your-redshift-endpoint',
       port=5439,
       database_name='targetdb',
       username='admin',
       password='your-password'
   )
   ```

3. **Create Migration Task**:
   ```python
   with open('../../../config/examples/table-mappings.json') as f:
       table_mappings = f.read()
   
   task = dms.create_replication_task(
       task_identifier='migration-task',
       source_endpoint_arn=source_endpoint['EndpointArn'],
       target_endpoint_arn=target_endpoint['EndpointArn'],
       replication_instance_arn='your-instance-arn',
       migration_type='full-load-and-cdc',
       table_mappings=table_mappings
   )
   ```

4. **Start Migration**:
   ```python
   dms.start_replication_task(task['ReplicationTaskArn'])
   ```

### Monitor Migration

```python
from monitors import DMSMonitor

monitor = DMSMonitor(region_name='us-west-2')
monitor.monitor_task_progress(
    task_arn=task['ReplicationTaskArn'],
    interval=60  # Check every 60 seconds
)
```

### Validate Data

```python
from validators import DataValidator

source_config = {
    'host': 'your-rds-endpoint',
    'port': 5432,
    'database': 'sourcedb',
    'username': 'postgres',
    'password': 'your-password'
}

target_config = {
    'host': 'your-redshift-endpoint',
    'port': 5439,
    'database': 'targetdb',
    'username': 'admin',
    'password': 'your-password'
}

validator = DataValidator(source_config, target_config)
results = validator.validate_row_counts([
    {'schema': 'public', 'table': 'your_table'}
])

for result in results:
    print(f"{result.table_name}: {result.message}")
```

## Common Commands

```bash
# Check Terraform state
terraform show

# Update infrastructure
terraform apply

# Destroy everything (when done)
terraform destroy

# View logs
aws logs tail /aws/dms/tasks/migration-task --follow

# Check DMS task status
aws dms describe-replication-tasks \
  --filters Name=replication-task-id,Values=migration-task
```

## Troubleshooting Quick Fixes

### Issue: Terraform init fails
```bash
# Solution: Check Terraform version
terraform version  # Should be 1.0+

# Upgrade if needed
brew upgrade terraform  # macOS
# or download from terraform.io
```

### Issue: AWS credentials not found
```bash
# Solution: Verify AWS CLI configuration
aws sts get-caller-identity --profile source-account
aws sts get-caller-identity --profile target-account
```

### Issue: Python module not found
```bash
# Solution: Ensure virtual environment is activated
source venv/bin/activate
pip install -r requirements.txt
```

### Issue: DMS endpoint connection fails
- Check security group rules allow port 5432 (PostgreSQL) or 5439 (Redshift)
- Verify VPC peering is active
- Test database connectivity manually

### Issue: Migration task fails
1. Check CloudWatch Logs: `/aws/dms/tasks/{task-id}`
2. Review table mappings JSON syntax
3. Verify database user has required permissions
4. Check for data type compatibility issues

## Cost Estimate (Dev Environment)

Approximate hourly costs:
- DMS t3.small instance: $0.073/hour
- RDS t3.small PostgreSQL: $0.034/hour
- Redshift dc2.large (2 nodes): $0.50/hour
- NAT Gateway: $0.045/hour
- **Total: ~$0.65/hour or ~$15/day**

💡 **Tip**: Remember to destroy resources when not in use to avoid costs!

```bash
terraform destroy
```

## Next Steps

1. Review the [100-Step Complete Guide](100-STEP-COMPLETE-GUIDE.md) for comprehensive instructions
2. Check [Architecture Documentation](../diagrams/ARCHITECTURE.md) to understand the design
3. Read [FAQ](../troubleshooting/FAQ.md) for common questions
4. Explore Python utilities in `python/src/`
5. Customize Terraform modules for your needs

## Need Help?

- 📖 Read the documentation in `docs/`
- 🐛 Report issues on GitHub
- 💬 Check the FAQ
- 📧 Contact the data engineering team

---

**Happy Migrating! 🚀**
