# modules/rds/main.tf
# RDS PostgreSQL 16: db.t3.micro, 20GB gp3, strictly private in 2 AZ subnets

resource "aws_db_subnet_group" "rds" {
  name        = "${var.project_name}-db-subnet-group"
  description = "RDS private database subnet group across 2 AZs"
  subnet_ids  = var.subnet_ids

  tags = {
    Name    = "${var.project_name}-db-subnet-group"
    Project = var.project_name
  }
}

resource "aws_db_parameter_group" "rds" {
  name        = "${var.project_name}-pg16-params"
  family      = "postgres16"
  description = "Custom parameter group for PostgreSQL 16"

  parameter {
    name  = "rds.force_ssl"
    value = "0"
  }

  tags = {
    Name    = "${var.project_name}-pg16-params"
    Project = var.project_name
  }
}

resource "aws_db_instance" "postgres" {
  identifier                  = "${var.project_name}-rds"
  engine                      = "postgres"
  engine_version              = "16.9"
  auto_minor_version_upgrade  = true
  instance_class              = var.db_instance_class
  allocated_storage           = 20
  max_allocated_storage       = 50
  storage_type                = "gp3"
  db_name                     = var.db_name
  username                    = var.db_username
  password                    = var.db_password
  db_subnet_group_name        = aws_db_subnet_group.rds.name
  parameter_group_name        = aws_db_parameter_group.rds.name
  vpc_security_group_ids      = [var.security_group_id]
  publicly_accessible         = false
  multi_az                    = false # Single-AZ for budget efficiency in lab
  skip_final_snapshot         = true  # Lab teardown setting
  deletion_protection         = false # Allow teardown when required
  allow_major_version_upgrade = false

  tags = {
    Name    = "${var.project_name}-postgres-rds"
    Project = var.project_name
  }
}
