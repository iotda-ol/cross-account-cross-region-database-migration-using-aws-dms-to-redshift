terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket-ACCOUNT_ID"
    key            = "dms-migration/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
