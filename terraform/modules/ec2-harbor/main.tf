# modules/ec2-harbor/main.tf
variable "project_name" { type = string }
variable "subnet_id" { type = string }
variable "security_group_id" { type = string }
variable "key_pair_name" { type = string }

# Placeholder EC2 & EIP for Harbor
resource "aws_eip" "harbor" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-harbor-eip" }
}

output "elastic_ip" {
  value = aws_eip.harbor.public_ip
}
