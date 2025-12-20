# Cross-Account Cross-Region Database Migration using AWS DMS to Redshift

[![Terraform](https://img.shields.io/badge/Terraform-1.0+-623CE4?logo=terraform)](https://www.terraform.io/)
[![Python](https://img.shields.io/badge/Python-3.9+-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![AWS](https://img.shields.io/badge/AWS-DMS-FF9900?logo=amazon-aws)](https://aws.amazon.com/dms/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

This repository demonstrates a **production-ready**, **highly modular** cross-account, cross-region database migration using AWS Database Migration Service (DMS). Data is replicated from Amazon RDS for PostgreSQL to Amazon Redshift by deploying the DMS replication instance in the target AWS account and region.

## 🌟 Key Features

- **100-Step Complete Guide**: From novice to expert, comprehensive step-by-step instructions
- **Maximum Modularity**: Reusable Terraform modules and Python utilities
- **Best Practices**: Following AWS Well-Architected Framework and DEA-C01 certification standards
- **Production-Ready**: Security, monitoring, logging, and error handling built-in
- **Cross-Account Architecture**: Proper IAM roles and policies for secure cross-account access
- **Cross-Region Support**: Optimized for cross-region data replication
- **Comprehensive Tooling**: Python utilities for validation, monitoring, and automation

## 📚 Documentation

### Quick Start
- [100-Step Complete Guide](docs/guides/100-STEP-COMPLETE-GUIDE.md) - Comprehensive guide from beginner to expert

### Architecture
- **Architecture Diagrams**: See `docs/diagrams/` for visual representations
- **Design Decisions**: Documented in each module's README

### Guides
- **Troubleshooting**: See `docs/troubleshooting/` for common issues and solutions
- **API Documentation**: See `docs/api/` for detailed API references

## 🏗️ Project Structure

```
.
├── terraform/                      # Infrastructure as Code
│   ├── modules/                   # Reusable Terraform modules
│   │   ├── networking/           # VPC, subnets, routing
│   │   ├── dms/                  # DMS replication instance
│   │   ├── rds/                  # PostgreSQL source database
│   │   ├── redshift/             # Redshift target cluster
│   │   ├── iam/                  # IAM roles and policies
│   │   ├── s3/                   # S3 bucket for DMS
│   │   └── monitoring/           # CloudWatch monitoring
│   └── environments/             # Environment-specific configurations
│       ├── dev/
│       ├── staging/
│       └── prod/
├── python/                        # Python utilities and scripts
│   ├── src/                      # Source code
│   │   ├── dms_manager/         # DMS task management
│   │   ├── validators/          # Data validation utilities
│   │   ├── monitors/            # Monitoring and alerting
│   │   └── utils/               # Common utilities
│   ├── tests/                   # Unit and integration tests
│   └── scripts/                 # Automation scripts
├── config/                       # Configuration files
│   ├── templates/               # Configuration templates
│   └── examples/                # Example configurations
├── docs/                        # Documentation
│   ├── guides/                 # User guides
│   ├── diagrams/               # Architecture diagrams
│   ├── troubleshooting/        # Troubleshooting guides
│   └── api/                    # API documentation
└── scripts/                     # Deployment and utility scripts
    ├── deployment/
    ├── validation/
    └── rollback/
```

## 🚀 Quick Start

### Prerequisites

1. **AWS Accounts**: Two AWS accounts (source and target)
2. **AWS CLI**: Version 2.x or later
3. **Terraform**: Version 1.0 or later
4. **Python**: Version 3.9 or later
5. **Git**: For version control

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/iotda-ol/cross-account-cross-region-database-migration-using-aws-dms-to-redshift.git
   cd cross-account-cross-region-database-migration-using-aws-dms-to-redshift
   ```

2. **Set up Python environment**:
   ```bash
   cd python/
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r requirements.txt
   ```

3. **Configure AWS credentials**:
   ```bash
   aws configure --profile source-account
   aws configure --profile target-account
   ```

4. **Configure Terraform variables**:
   ```bash
   cd terraform/environments/dev/
   cp ../../../config/examples/terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

5. **Initialize Terraform**:
   ```bash
   terraform init
   ```

6. **Deploy infrastructure**:
   ```bash
   terraform plan
   terraform apply
   ```

## 📖 Usage

### Deploy Complete Infrastructure

```bash
cd terraform/environments/dev/
terraform apply
```

### Create DMS Endpoints and Tasks

```python
from dms_manager import DMSManager

# Initialize DMS manager
dms = DMSManager(region_name='us-west-2')

# Create source endpoint
source_endpoint = dms.create_endpoint(
    endpoint_identifier='source-postgres',
    endpoint_type='source',
    engine_name='postgres',
    server_name='your-rds-endpoint.amazonaws.com',
    port=5432,
    database_name='sourcedb',
    username='postgres',
    password='your-password'
)

# Create replication task
task = dms.create_replication_task(
    task_identifier='migration-task',
    source_endpoint_arn=source_endpoint['EndpointArn'],
    target_endpoint_arn=target_endpoint['EndpointArn'],
    replication_instance_arn='your-replication-instance-arn',
    migration_type='full-load-and-cdc',
    table_mappings=table_mappings_json
)
```

### Validate Migration

```python
from validators import DataValidator

# Initialize validator
validator = DataValidator(source_config, target_config)

# Validate row counts
results = validator.validate_row_counts([
    {'schema': 'public', 'table': 'users'},
    {'schema': 'public', 'table': 'orders'}
])

for result in results:
    print(f"{result.table_name}: {result.message}")
```

### Monitor Migration

```python
from monitors import DMSMonitor

# Initialize monitor
monitor = DMSMonitor(region_name='us-west-2')

# Monitor task progress
monitor.monitor_task_progress(
    task_arn='your-task-arn',
    interval=60
)
```

## 🔧 Configuration

### Terraform Variables

Key variables to configure in `terraform.tfvars`:

- `project_name`: Name for your project
- `source_account_id`: AWS account ID for source
- `target_account_id`: AWS account ID for target
- `vpc_cidr`: CIDR block for VPC
- `availability_zones`: List of AZs to use
- Database credentials and instance sizes

See `config/examples/terraform.tfvars.example` for complete configuration.

### DMS Task Settings

Configure task settings in `config/examples/task-settings.json`:

- Target table preparation mode
- LOB handling
- Parallel load settings
- Error handling policies
- Validation settings

### Table Mappings

Define table selection and transformation rules in `config/examples/table-mappings.json`.

## 🧪 Testing

### Run Python Tests

```bash
cd python/
pytest tests/ -v
```

### Validate Terraform

```bash
cd terraform/environments/dev/
terraform validate
terraform fmt -check -recursive
```

## 📊 Monitoring

### CloudWatch Metrics

Key metrics monitored:
- `FullLoadThroughputRowsSource`: Source data load rate
- `FullLoadThroughputRowsTarget`: Target data load rate
- `CDCLatencySource`: Change data capture latency
- `NetworkTransmitThroughput`: Network transfer rate

### Logs

- DMS task logs: `/aws/dms/tasks/{task-id}`
- VPC flow logs: `/aws/vpc/{vpc-id}`
- Application logs: `/aws/lambda/{function-name}`

## 🔒 Security

- **Encryption at Rest**: All data encrypted using AWS KMS
- **Encryption in Transit**: SSL/TLS for all database connections
- **IAM Roles**: Least privilege access with proper role assumption
- **Security Groups**: Restricted network access
- **Secrets Management**: Use AWS Secrets Manager (recommended)
- **VPC Flow Logs**: Network traffic monitoring

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

- **Issues**: Report bugs via GitHub Issues
- **Documentation**: See `docs/` directory
- **Troubleshooting**: See `docs/troubleshooting/FAQ.md`

## 🙏 Acknowledgments

- AWS Database Migration Service documentation
- Terraform AWS Provider documentation
- PostgreSQL and Redshift communities

## 📌 Roadmap

- [ ] Add support for Oracle and MySQL sources
- [ ] Implement automated rollback procedures
- [ ] Add Terraform state management examples
- [ ] Create Ansible playbooks for deployment
- [ ] Add performance benchmarking tools
- [ ] Implement cost optimization recommendations

---

**Built with ❤️ for the data engineering community**
