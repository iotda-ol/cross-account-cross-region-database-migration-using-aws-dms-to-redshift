#!/usr/bin/env python3
"""
Pre-migration validation script
Checks prerequisites before starting migration
"""

import sys
import json
import logging
import argparse
import boto3
from typing import Dict, List, Tuple

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class PreMigrationValidator:
    """Validates prerequisites before migration"""

    def __init__(self, config_file: str):
        """Initialize validator with configuration"""
        with open(config_file, 'r') as f:
            self.config = json.load(f)
        
        self.checks_passed = []
        self.checks_failed = []

    def check_aws_credentials(self) -> bool:
        """Check AWS credentials are configured"""
        try:
            sts = boto3.client('sts')
            identity = sts.get_caller_identity()
            logger.info(f"AWS credentials valid for account: {identity['Account']}")
            return True
        except Exception as e:
            logger.error(f"AWS credentials check failed: {e}")
            return False

    def check_vpc_connectivity(self) -> bool:
        """Check VPC and networking setup"""
        try:
            ec2 = boto3.client('ec2', region_name=self.config['region'])
            
            # Check VPC exists
            vpcs = ec2.describe_vpcs(VpcIds=[self.config['vpc_id']])
            if not vpcs['Vpcs']:
                logger.error(f"VPC {self.config['vpc_id']} not found")
                return False
            
            logger.info(f"VPC {self.config['vpc_id']} exists")
            
            # Check subnets
            subnets = ec2.describe_subnets(
                Filters=[{'Name': 'vpc-id', 'Values': [self.config['vpc_id']]}]
            )
            logger.info(f"Found {len(subnets['Subnets'])} subnets")
            
            return True
        except Exception as e:
            logger.error(f"VPC connectivity check failed: {e}")
            return False

    def check_rds_availability(self) -> bool:
        """Check RDS instance is available"""
        try:
            rds = boto3.client('rds', region_name=self.config['source_region'])
            response = rds.describe_db_instances(
                DBInstanceIdentifier=self.config['source_db_instance']
            )
            
            instance = response['DBInstances'][0]
            status = instance['DBInstanceStatus']
            
            if status != 'available':
                logger.warning(f"RDS instance status: {status}")
                return False
            
            logger.info(f"RDS instance {self.config['source_db_instance']} is available")
            return True
        except Exception as e:
            logger.error(f"RDS availability check failed: {e}")
            return False

    def check_redshift_availability(self) -> bool:
        """Check Redshift cluster is available"""
        try:
            redshift = boto3.client('redshift', region_name=self.config['target_region'])
            response = redshift.describe_clusters(
                ClusterIdentifier=self.config['target_cluster']
            )
            
            cluster = response['Clusters'][0]
            status = cluster['ClusterStatus']
            
            if status != 'available':
                logger.warning(f"Redshift cluster status: {status}")
                return False
            
            logger.info(f"Redshift cluster {self.config['target_cluster']} is available")
            return True
        except Exception as e:
            logger.error(f"Redshift availability check failed: {e}")
            return False

    def check_iam_roles(self) -> bool:
        """Check required IAM roles exist"""
        try:
            iam = boto3.client('iam')
            
            required_roles = [
                'dms-vpc-role',
                'dms-cloudwatch-logs-role'
            ]
            
            for role_name in required_roles:
                try:
                    iam.get_role(RoleName=role_name)
                    logger.info(f"IAM role {role_name} exists")
                except iam.exceptions.NoSuchEntityException:
                    logger.error(f"Required IAM role {role_name} not found")
                    return False
            
            return True
        except Exception as e:
            logger.error(f"IAM roles check failed: {e}")
            return False

    def check_s3_bucket(self) -> bool:
        """Check S3 bucket exists and is accessible"""
        try:
            s3 = boto3.client('s3')
            bucket_name = self.config.get('s3_bucket')
            
            if not bucket_name:
                logger.warning("S3 bucket not configured")
                return True  # Optional check
            
            s3.head_bucket(Bucket=bucket_name)
            logger.info(f"S3 bucket {bucket_name} is accessible")
            return True
        except Exception as e:
            logger.error(f"S3 bucket check failed: {e}")
            return False

    def check_security_groups(self) -> bool:
        """Check security group rules"""
        try:
            ec2 = boto3.client('ec2', region_name=self.config['region'])
            
            # Check if security groups allow required ports
            sg_id = self.config.get('security_group_id')
            if not sg_id:
                logger.warning("Security group not configured")
                return True
            
            response = ec2.describe_security_groups(GroupIds=[sg_id])
            sg = response['SecurityGroups'][0]
            
            # Check for PostgreSQL port (5432)
            postgres_allowed = any(
                rule.get('FromPort') == 5432 
                for rule in sg.get('IpPermissions', [])
            )
            
            # Check for Redshift port (5439)
            redshift_allowed = any(
                rule.get('FromPort') == 5439 
                for rule in sg.get('IpPermissions', [])
            )
            
            if not postgres_allowed:
                logger.warning("PostgreSQL port 5432 not allowed in security group")
            if not redshift_allowed:
                logger.warning("Redshift port 5439 not allowed in security group")
            
            logger.info("Security group rules checked")
            return True
        except Exception as e:
            logger.error(f"Security groups check failed: {e}")
            return False

    def run_all_checks(self) -> Tuple[List[str], List[str]]:
        """Run all validation checks"""
        checks = {
            'AWS Credentials': self.check_aws_credentials,
            'VPC Connectivity': self.check_vpc_connectivity,
            'RDS Availability': self.check_rds_availability,
            'Redshift Availability': self.check_redshift_availability,
            'IAM Roles': self.check_iam_roles,
            'S3 Bucket': self.check_s3_bucket,
            'Security Groups': self.check_security_groups
        }
        
        logger.info("=" * 60)
        logger.info("Starting pre-migration validation checks")
        logger.info("=" * 60)
        
        for check_name, check_func in checks.items():
            logger.info(f"\nRunning check: {check_name}")
            try:
                if check_func():
                    self.checks_passed.append(check_name)
                    logger.info(f"✓ {check_name} passed")
                else:
                    self.checks_failed.append(check_name)
                    logger.error(f"✗ {check_name} failed")
            except Exception as e:
                self.checks_failed.append(check_name)
                logger.error(f"✗ {check_name} failed with exception: {e}")
        
        logger.info("\n" + "=" * 60)
        logger.info("Validation Summary")
        logger.info("=" * 60)
        logger.info(f"Checks passed: {len(self.checks_passed)}/{len(checks)}")
        logger.info(f"Checks failed: {len(self.checks_failed)}/{len(checks)}")
        
        if self.checks_passed:
            logger.info("\nPassed checks:")
            for check in self.checks_passed:
                logger.info(f"  ✓ {check}")
        
        if self.checks_failed:
            logger.error("\nFailed checks:")
            for check in self.checks_failed:
                logger.error(f"  ✗ {check}")
        
        logger.info("=" * 60)
        
        return self.checks_passed, self.checks_failed


def main():
    parser = argparse.ArgumentParser(
        description='Pre-migration validation script'
    )
    parser.add_argument(
        '--config',
        required=True,
        help='Path to configuration file'
    )
    
    args = parser.parse_args()
    
    validator = PreMigrationValidator(args.config)
    passed, failed = validator.run_all_checks()
    
    if failed:
        logger.error("\nPre-migration validation failed!")
        logger.error("Please fix the issues above before proceeding.")
        sys.exit(1)
    else:
        logger.info("\n✓ All pre-migration checks passed!")
        logger.info("You can proceed with the migration.")
        sys.exit(0)


if __name__ == '__main__':
    main()
