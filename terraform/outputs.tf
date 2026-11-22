# terraform/outputs.tf
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "harbor_public_ip" {
  description = "Elastic IP of EC2 Harbor - used for nip.io domain"
  value       = module.ec2_harbor.elastic_ip
}

output "harbor_private_ip" {
  description = "Private IP of EC2 Harbor inside VPC"
  value       = module.ec2_harbor.private_ip
}

output "k3s_server_public_ip" {
  description = "Elastic IP of K3s Server - used for kubeconfig and ingress domain"
  value       = module.ec2_k3s.server_elastic_ip
}

output "k3s_server_private_ip" {
  description = "Private IP of K3s Server inside VPC"
  value       = module.ec2_k3s.server_private_ip
}

output "k3s_worker_public_ip" {
  description = "Public IP of K3s Worker (egress IP)"
  value       = module.ec2_k3s.worker_public_ip
}

output "k3s_worker_private_ip" {
  description = "Private IP of K3s Worker inside VPC"
  value       = module.ec2_k3s.worker_private_ip
}

output "rds_endpoint" {
  description = "RDS connection endpoint host:port - injected into K8s ConfigMap"
  value       = module.rds.db_endpoint
  sensitive   = true
}

output "rds_address" {
  description = "RDS hostname address - injected into DB_HOST"
  value       = module.rds.db_address
  sensitive   = true
}

output "rds_port" {
  description = "RDS database port"
  value       = module.rds.db_port
}

output "sg_ids" {
  description = "Security Group IDs - referenced in Ansible inventory and verification"
  value = {
    harbor     = module.security.sg_harbor_id
    k3s_server = module.security.sg_k3s_server_id
    k3s_worker = module.security.sg_k3s_worker_id
    rds        = module.security.sg_rds_id
  }
}
