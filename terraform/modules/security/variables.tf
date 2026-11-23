# modules/security/variables.tf
variable "vpc_id" {
  description = "Target VPC ID"
  type        = string
}

variable "project_name" {
  description = "Project name prefix"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.project_name)) && !startswith(var.project_name, "sg-")
    error_message = "Project name must contain only lowercase alphanumeric characters and hyphens, cannot start with 'sg-', and must start and end with an alphanumeric character."
  }
}

variable "my_ip_cidr" {
  description = "Admin public IP CIDR for SSH and K8s API access"
  type        = string

  validation {
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}/32$", var.my_ip_cidr)) && can(cidrhost(var.my_ip_cidr, 0))
    error_message = "Must be a single IPv4 host CIDR block with /32 prefix (e.g. 1.2.3.4/32)."
  }
}
