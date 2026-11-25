# modules/ec2-harbor/variables.tf
variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for Harbor EC2 (Public Subnet 2)"
  type        = string
}

variable "security_group_id" {
  description = "Security Group ID for Harbor"
  type        = string
}

variable "key_pair_name" {
  description = "SSH Key pair name"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile name (LabInstanceProfile on AWS Academy)"
  type        = string
  default     = "LabInstanceProfile"
}

variable "instance_type" {
  description = "EC2 instance type for Harbor"
  type        = string
  default     = "t3.medium"
}
