# modules/ec2-k3s/outputs.tf
output "server_elastic_ip" {
  description = "Elastic IP of K3s Server"
  value       = aws_eip.k3s_server.public_ip
}

output "server_private_ip" {
  description = "Private IP of K3s Server"
  value       = aws_instance.k3s_server.private_ip
}

output "server_instance_id" {
  description = "Instance ID of K3s Server"
  value       = aws_instance.k3s_server.id
}

output "worker_public_ip" {
  description = "Public IP of K3s Worker (egress IP)"
  value       = aws_instance.k3s_worker.public_ip
}

output "worker_private_ip" {
  description = "Private IP of K3s Worker"
  value       = aws_instance.k3s_worker.private_ip
}

output "worker_instance_id" {
  description = "Instance ID of K3s Worker"
  value       = aws_instance.k3s_worker.id
}
