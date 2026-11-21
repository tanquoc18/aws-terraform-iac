# modules/rds/main.tf
variable "project_name"      { type = string }
variable "subnet_ids"        { type = list(string) }
variable "security_group_id" { type = string }
variable "db_username"       { type = string }
variable "db_password"       { type = string; sensitive = true }
variable "db_name"           { type = string }

output "db_endpoint" {
  value = "mock-rds-endpoint.postgres.us-east-1.rds.amazonaws.com"
}
