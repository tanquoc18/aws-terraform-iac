# terraform/outputs.tf
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "harbor_public_ip" {
  description = "Elastic IP của EC2 Harbor – dùng làm nip.io domain"
  value       = module.ec2_harbor.elastic_ip
}

output "k3s_server_public_ip" {
  description = "Elastic IP của K3s Server – dùng cho kubeconfig và nip.io"
  value       = module.ec2_k3s.server_elastic_ip
}

output "k3s_worker_public_ip" {
  description = "Public IP K3s Worker (thay đổi sau restart)"
  value       = module.ec2_k3s.worker_public_ip
}

output "rds_endpoint" {
  description = "RDS hostname – điền vào K8s ConfigMap DB_HOST"
  value       = module.rds.db_endpoint
  sensitive   = true
}

output "sg_ids" {
  description = "Security Group IDs – dùng cho Ansible inventory"
  value = {
    harbor     = module.security.sg_harbor_id
    k3s_server = module.security.sg_k3s_server_id
    k3s_worker = module.security.sg_k3s_worker_id
    rds        = module.security.sg_rds_id
  }
}
