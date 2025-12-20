# Source Account Configuration

## RDS Instance
- Endpoint: YOUR_RDS_ENDPOINT
- Port: 5432
- Database: YOUR_DATABASE
- Replication User: dms_user

## IAM Role
- Role ARN: arn:aws:iam::SOURCE_ACCOUNT_ID:role/DMSCrossAccountRole

## Replication Slot
- Slot Name: dms_replication_slot
- Plugin: pglogical

## Security Group
- ID: sg-xxxxx
