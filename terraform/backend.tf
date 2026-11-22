# terraform/backend.tf
# S3 Remote State + S3 Native State Locking (Terraform >= 1.11.0)
# KHÔNG cần DynamoDB – dùng S3 Conditional Writes thay thế

terraform {
  required_version = ">= 1.11.0"

  backend "s3" {
    bucket       = "devops-lab-tfstate-us-east-1" # Tạo bởi bootstrap/
    key          = "infrastructure/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # S3 Native State Locking – GA từ Terraform 1.11+
    # Không cần dynamodb_table nữa!
  }
}
