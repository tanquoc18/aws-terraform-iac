# modules/rds/variables.tf
variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs for DB subnet group (2 AZs required)"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security Group ID for RDS (Worker-only 5432)"
  type        = string
}

variable "db_instance_class" {
  description = "RDS DB instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_username" {
  description = "Master username for database"
  type        = string
  default     = "appuser"
}

variable "db_password" {
  description = "Master password for database"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "appdb"
}
