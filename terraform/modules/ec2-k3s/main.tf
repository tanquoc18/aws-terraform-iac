# modules/ec2-k3s/main.tf
variable "project_name" { type = string }
variable "subnet_id"    { type = string }
variable "sg_server_id" { type = string }
variable "sg_worker_id" { type = string }
variable "key_pair_name"{ type = string }

resource "aws_eip" "k3s_server" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-k3s-server-eip" }
}

output "server_elastic_ip" {
  value = aws_eip.k3s_server.public_ip
}

output "worker_public_ip" {
  value = "10.0.1.50" # Placeholder IP/Output
}
