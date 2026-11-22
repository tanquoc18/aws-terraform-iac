# terraform/main.tf - Infrastructure Orchestrator (Phase 2)

module "vpc" {
  source             = "./modules/vpc"
  project_name       = var.project_name
  environment        = var.environment
  aws_region         = var.aws_region
  availability_zones = var.availability_zones
}

module "security" {
  source       = "./modules/security"
  vpc_id       = module.vpc.vpc_id
  project_name = var.project_name
  my_ip_cidr   = var.my_ip_cidr
}

module "ec2_harbor" {
  source               = "./modules/ec2-harbor"
  project_name         = var.project_name
  subnet_id            = module.vpc.public_subnet_ids[1] # Public Subnet 2 (AZ 2)
  security_group_id    = module.security.sg_harbor_id
  key_pair_name        = var.key_pair_name
  iam_instance_profile = var.iam_instance_profile
}

module "ec2_k3s" {
  source               = "./modules/ec2-k3s"
  project_name         = var.project_name
  subnet_id            = module.vpc.public_subnet_ids[0] # Public Subnet 1 (AZ 1)
  sg_server_id         = module.security.sg_k3s_server_id
  sg_worker_id         = module.security.sg_k3s_worker_id
  key_pair_name        = var.key_pair_name
  iam_instance_profile = var.iam_instance_profile
}

module "rds" {
  source            = "./modules/rds"
  project_name      = var.project_name
  subnet_ids        = module.vpc.private_subnet_ids # 2 Private DB Subnets across 2 AZs
  security_group_id = module.security.sg_rds_id
  db_instance_class = var.db_instance_class
  db_username       = var.db_username
  db_password       = var.db_password
  db_name           = var.db_name
}
