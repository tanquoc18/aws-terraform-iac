output "sg_k3s_server_id" { value = aws_security_group.k3s_server.id }
output "sg_k3s_worker_id" { value = aws_security_group.k3s_worker.id }
output "sg_rds_id"        { value = aws_security_group.rds.id }
output "sg_harbor_id"     { value = aws_security_group.harbor.id }
