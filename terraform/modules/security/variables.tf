# modules/security/variables.tf
variable "vpc_id" {
  description = "Target VPC ID"
  type        = string
}

variable "project_name" {
  description = "Project name prefix"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase alphanumeric characters and hyphens."
  }
}

variable "my_ip_cidr" {
  description = "Admin public IP CIDR for SSH and K8s API access"
  type        = string

  validation {
    condition     = can(cidrhost(var.my_ip_cidr, 0)) && can(cidrnetmask(var.my_ip_cidr))
    error_message = "Must be a valid IPv4 CIDR block (e.g. 1.2.3.4/32)."
  }
}
