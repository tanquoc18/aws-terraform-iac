# modules/vpc/variables.tf
variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "availability_zones" {
  description = "List of 2 availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}
