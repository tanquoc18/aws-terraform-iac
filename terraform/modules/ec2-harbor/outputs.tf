# modules/ec2-harbor/outputs.tf
output "elastic_ip" {
  description = "Allocated Elastic IP for Harbor"
  value       = aws_eip.harbor.public_ip
}

output "instance_id" {
  description = "Harbor EC2 instance ID"
  value       = aws_instance.harbor.id
}

output "private_ip" {
  description = "Harbor EC2 private IP"
  value       = aws_instance.harbor.private_ip
}

output "data_volume_id" {
  description = "Harbor dedicated 60GB EBS volume ID"
  value       = aws_ebs_volume.harbor_data.id
}
