# terraform/providers.tf
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "DevOps-2Tier"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
