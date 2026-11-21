# terraform/variables.tf
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (lab / staging / prod)"
  type        = string
  default     = "lab"
}

variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
  default     = "devops-2tier"
}

variable "my_ip_cidr" {
  description = "Your public IP/32 for SSH and K8s API admin access"
  type        = string
  # Lấy IP: curl ifconfig.me
  # Điền vào terraform.tfvars: my_ip_cidr = "1.2.3.4/32"
}

variable "key_pair_name" {
  description = "AWS EC2 Key Pair name for SSH access"
  type        = string
}

variable "db_password" {
  description = "RDS PostgreSQL master password (sensitive)"
  type        = string
  sensitive   = true
}

variable "db_username" {
  description = "RDS PostgreSQL master username"
  type        = string
  default     = "appuser"
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "appdb"
}
