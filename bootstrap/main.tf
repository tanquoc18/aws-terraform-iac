# bootstrap/main.tf
# Mục đích: Tạo S3 Bucket lưu Terraform Remote State (chạy 1 lần duy nhất)
# Chạy trước khi init terraform/ chính
# KHÔNG dùng remote backend ở đây (chicken-and-egg problem)

terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.30"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  default = "us-east-1"
}

variable "bucket_name" {
  default     = "devops-lab-tfstate-us-east-1"
  description = "Tên S3 bucket lưu Terraform state (phải globally unique)"
}

resource "aws_s3_bucket" "tfstate" {
  bucket        = var.bucket_name
  force_destroy = false # Bảo vệ state khỏi xóa nhầm
  tags = {
    Name      = "Terraform State Bucket"
    Project   = "DevOps-2Tier"
    ManagedBy = "Terraform-Bootstrap"
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled" # Bật versioning để rollback state nếu cần
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # SSE-S3 (không tốn phí KMS)
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
