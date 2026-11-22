# terraform/variables.tf
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "List of 2 availability zones to deploy public and private subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Exactly 2 availability zones must be provided."
  }
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

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase alphanumeric characters and hyphens."
  }
}

variable "my_ip_cidr" {
  description = "Your public IP/32 for SSH and K8s API admin access"
  type        = string

  validation {
    condition     = can(cidrhost(var.my_ip_cidr, 0)) && can(cidrnetmask(var.my_ip_cidr))
    error_message = "Must be a valid IPv4 CIDR block (e.g. 1.2.3.4/32)."
  }
}

variable "key_pair_name" {
  description = "AWS EC2 Key Pair name for SSH access"
  type        = string
  default     = "vockey"
}

variable "iam_instance_profile" {
  description = "IAM instance profile name for EC2 instances (pre-existing in AWS Academy)"
  type        = string
  default     = "LabInstanceProfile"
}

variable "db_instance_class" {
  description = "RDS DB instance class"
  type        = string
  default     = "db.t3.micro"
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
