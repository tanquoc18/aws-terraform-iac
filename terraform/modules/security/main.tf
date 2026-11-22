# modules/security/main.tf
# Security Group Chaining - PHASE 2 strict security design
# All descriptions are strict ASCII. Using separate aws_vpc_security_group_ingress_rule
# resources with referenced_security_group_id for deterministic chaining.

locals {
  name_prefix = var.project_name
}

# ==============================================================
# 1. SECURITY GROUP DEFINITIONS (Resources without inline rules)
# ==============================================================

resource "aws_security_group" "k3s_server" {
  name        = "${local.name_prefix}-k3s-server"
  description = "K3s Control Plane and Traefik Ingress public entrypoint"
  vpc_id      = var.vpc_id
  tags        = { Name = "sg-k3s-server", Project = var.project_name }

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "k3s_worker" {
  name        = "${local.name_prefix}-k3s-worker"
  description = "K3s Worker Node - zero inbound from public internet"
  vpc_id      = var.vpc_id
  tags        = { Name = "sg-k3s-worker", Project = var.project_name }

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds"
  description = "RDS PostgreSQL - ingress restricted strictly to k3s worker"
  vpc_id      = var.vpc_id
  tags        = { Name = "sg-rds", Project = var.project_name }

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "harbor" {
  name        = "${local.name_prefix}-harbor"
  description = "Harbor Registry - public push and K3s cluster pull"
  vpc_id      = var.vpc_id
  tags        = { Name = "sg-harbor", Project = var.project_name }

  lifecycle { create_before_destroy = true }
}

# ==============================================================
# 2. SG-K3S-SERVER: INBOUND RULES
# ==============================================================

resource "aws_vpc_security_group_ingress_rule" "server_http" {
  security_group_id = aws_security_group.k3s_server.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  description       = "Public HTTP to Traefik Ingress"
}

resource "aws_vpc_security_group_ingress_rule" "server_https" {
  security_group_id = aws_security_group.k3s_server.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "Public HTTPS to Traefik Ingress"
}

resource "aws_vpc_security_group_ingress_rule" "server_k8s_api_myip" {
  security_group_id = aws_security_group.k3s_server.id
  cidr_ipv4         = var.my_ip_cidr
  ip_protocol       = "tcp"
  from_port         = 6443
  to_port           = 6443
  description       = "K3s API admin access from trusted My IP only"
}

resource "aws_vpc_security_group_ingress_rule" "server_k8s_api_from_worker" {
  security_group_id            = aws_security_group.k3s_server.id
  referenced_security_group_id = aws_security_group.k3s_worker.id
  ip_protocol                  = "tcp"
  from_port                    = 6443
  to_port                      = 6443
  description                  = "K3s Agent worker registration to Server API"
}

resource "aws_vpc_security_group_ingress_rule" "server_vxlan_from_worker" {
  security_group_id            = aws_security_group.k3s_server.id
  referenced_security_group_id = aws_security_group.k3s_worker.id
  ip_protocol                  = "udp"
  from_port                    = 8472
  to_port                      = 8472
  description                  = "Flannel VXLAN Overlay from Worker"
}

resource "aws_vpc_security_group_ingress_rule" "server_kubelet_from_worker" {
  security_group_id            = aws_security_group.k3s_server.id
  referenced_security_group_id = aws_security_group.k3s_worker.id
  ip_protocol                  = "tcp"
  from_port                    = 10250
  to_port                      = 10250
  description                  = "Kubelet metrics from Worker"
}

resource "aws_vpc_security_group_ingress_rule" "server_ssh" {
  security_group_id = aws_security_group.k3s_server.id
  cidr_ipv4         = var.my_ip_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  description       = "SSH admin access from trusted My IP only"
}

# ==============================================================
# 3. SG-K3S-WORKER: INBOUND RULES (100 PERCENT BLOCKED FROM INTERNET)
# Zero 0.0.0.0/0 rules. Only specific ports from K3s Server SG.
# ==============================================================

resource "aws_vpc_security_group_ingress_rule" "worker_vxlan_from_server" {
  security_group_id            = aws_security_group.k3s_worker.id
  referenced_security_group_id = aws_security_group.k3s_server.id
  ip_protocol                  = "udp"
  from_port                    = 8472
  to_port                      = 8472
  description                  = "Flannel VXLAN Overlay from Server"
}

resource "aws_vpc_security_group_ingress_rule" "worker_kubelet_from_server" {
  security_group_id            = aws_security_group.k3s_worker.id
  referenced_security_group_id = aws_security_group.k3s_server.id
  ip_protocol                  = "tcp"
  from_port                    = 10250
  to_port                      = 10250
  description                  = "Kubelet API from Server for logs and exec"
}

resource "aws_vpc_security_group_ingress_rule" "worker_ssh_from_server" {
  security_group_id            = aws_security_group.k3s_worker.id
  referenced_security_group_id = aws_security_group.k3s_server.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  description                  = "Internal SSH jump from Server bastion only"
}

resource "aws_vpc_security_group_ingress_rule" "worker_node_exporter_self" {
  security_group_id            = aws_security_group.k3s_worker.id
  referenced_security_group_id = aws_security_group.k3s_worker.id
  ip_protocol                  = "tcp"
  from_port                    = 9100
  to_port                      = 9100
  description                  = "Prometheus internal scrape Node Exporter on Worker"
}

# ==============================================================
# 4. SG-RDS: INBOUND - STRICTLY FROM SG-K3S-WORKER ONLY
# ==============================================================

resource "aws_vpc_security_group_ingress_rule" "rds_postgres_from_worker" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.k3s_worker.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL 5432 strictly from K3s Worker pods only"
}
# No other ingress rules. Internet, K3s Server, and Harbor are strictly dropped.

# ==============================================================
# 5. SG-HARBOR: INBOUND RULES
# ==============================================================

resource "aws_vpc_security_group_ingress_rule" "harbor_http_public" {
  security_group_id = aws_security_group.harbor.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  description       = "Harbor Web UI HTTP redirect"
}

resource "aws_vpc_security_group_ingress_rule" "harbor_https_public" {
  security_group_id = aws_security_group.harbor.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "Harbor HTTPS registry API and Web UI"
}

resource "aws_vpc_security_group_ingress_rule" "harbor_https_from_worker" {
  security_group_id            = aws_security_group.harbor.id
  referenced_security_group_id = aws_security_group.k3s_worker.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "K3s Worker pull images from Harbor over VPC"
}

resource "aws_vpc_security_group_ingress_rule" "harbor_https_from_server" {
  security_group_id            = aws_security_group.harbor.id
  referenced_security_group_id = aws_security_group.k3s_server.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "K3s Server pull images from Harbor over VPC"
}

resource "aws_vpc_security_group_ingress_rule" "harbor_node_exporter_from_worker" {
  security_group_id            = aws_security_group.harbor.id
  referenced_security_group_id = aws_security_group.k3s_worker.id
  ip_protocol                  = "tcp"
  from_port                    = 9100
  to_port                      = 9100
  description                  = "Prometheus scrape Node Exporter on Harbor host"
}

resource "aws_vpc_security_group_ingress_rule" "harbor_ssh" {
  security_group_id = aws_security_group.harbor.id
  cidr_ipv4         = var.my_ip_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  description       = "SSH admin access from trusted My IP only"
}

# ==============================================================
# 6. EGRESS RULES (Outbound)
# ==============================================================

resource "aws_vpc_security_group_egress_rule" "server_egress_all" {
  security_group_id = aws_security_group.k3s_server.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "All outbound traffic allowed"
}

resource "aws_vpc_security_group_egress_rule" "worker_egress_all" {
  security_group_id = aws_security_group.k3s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Internet egress for downloading packages and base images"
}

resource "aws_vpc_security_group_egress_rule" "harbor_egress_all" {
  security_group_id = aws_security_group.harbor.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "All outbound for OS updates and Trivy vulnerability DB"
}

# sg-rds: Zero egress rules. Database never initiates outbound connections.
