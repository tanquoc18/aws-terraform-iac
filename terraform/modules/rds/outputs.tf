# modules/rds/outputs.tf
output "db_endpoint" {
  description = "RDS connection endpoint host:port"
  value       = aws_db_instance.postgres.endpoint
  sensitive   = true
}

output "db_address" {
  description = "RDS hostname (without port)"
  value       = aws_db_instance.postgres.address
  sensitive   = true
}

output "db_port" {
  description = "RDS database port"
  value       = aws_db_instance.postgres.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.postgres.db_name
}
