# modules/security/main.tf
# Security Group Chaining – Kế thừa Project 11
# Dùng aws_vpc_security_group_ingress_rule (resource riêng lẻ, không inline)
# để tham chiếu referenced_security_group_id tường minh

locals {
  name_prefix = var.project_name
}

# ══════════════════════════════════════════════════════════════
# 1. ĐỊNH NGHĨA CÁC SECURITY GROUPS (chỉ khai báo, không có rules)
# ══════════════════════════════════════════════════════════════

resource "aws_security_group" "k3s_server" {
  name        = "${local.name_prefix}-k3s-server"
  description = "K3s Control Plane & Traefik Ingress – Public entrypoint"
  vpc_id      = var.vpc_id
  tags        = { Name = "sg-k3s-server", Project = "DevOps-2Tier" }

  # Xóa toàn bộ egress default (sẽ khai báo riêng bên dưới)
  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "k3s_worker" {
  name        = "${local.name_prefix}-k3s-worker"
  description = "K3s Worker Node – CHẶN 100% Internet inbound"
  vpc_id      = var.vpc_id
  tags        = { Name = "sg-k3s-worker", Project = "DevOps-2Tier" }

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds"
  description = "RDS PostgreSQL – Chỉ nhận từ sg-k3s-worker"
  vpc_id      = var.vpc_id
  tags        = { Name = "sg-rds", Project = "DevOps-2Tier" }

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "harbor" {
  name        = "${local.name_prefix}-harbor"
  description = "Harbor Registry – Public push & K3s pull"
  vpc_id      = var.vpc_id
  tags        = { Name = "sg-harbor", Project = "DevOps-2Tier" }

  lifecycle { create_before_destroy = true }
}

# ══════════════════════════════════════════════════════════════
# 2. SG-K3S-SERVER: INBOUND RULES
# ══════════════════════════════════════════════════════════════

resource "aws_vpc_security_group_ingress_rule" "server_http" {
  security_group_id = aws_security_group.k3s_server.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  description       = "Public HTTP → Traefik Ingress"
}

resource "aws_vpc_security_group_ingress_rule" "server_https" {
  security_group_id = aws_security_group.k3s_server.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "Public HTTPS → Traefik Ingress"
}

resource "aws_vpc_security_group_ingress_rule" "server_k8s_api_myip" {
  security_group_id = aws_security_group.k3s_server.id
  cidr_ipv4         = var.my_ip_cidr
  ip_protocol       = "tcp"
  from_port         = 6443
  to_port           = 6443
  description       = "K3s API – Admin access from My IP"
}

resource "aws_vpc_security_group_ingress_rule" "server_k8s_api_from_worker" {
  security_group_id            = aws_security_group.k3s_server.id
  referenced_security_group_id = aws_security_group.k3s_worker.id # CHAINING
  ip_protocol                  = "tcp"
  from_port                    = 6443
  to_port                      = 6443
  description                  = "K3s Agent registration → Server API"
}

resource "aws_vpc_security_group_ingress_rule" "server_vxlan_from_worker" {
  security_group_id            = aws_security_group.k3s_server.id
  referenced_security_group_id = aws_security_group.k3s_worker.id # CHAINING
  ip_protocol                  = "udp"
  from_port                    = 8472
  to_port                      = 8472
  description                  = "Flannel VXLAN Overlay ← Worker"
}

resource "aws_vpc_security_group_ingress_rule" "server_kubelet_from_worker" {
  security_group_id            = aws_security_group.k3s_server.id
  referenced_security_group_id = aws_security_group.k3s_worker.id # CHAINING
  ip_protocol                  = "tcp"
  from_port                    = 10250
  to_port                      = 10250
  description                  = "Kubelet metrics ← Worker"
}

resource "aws_vpc_security_group_ingress_rule" "server_ssh" {
  security_group_id = aws_security_group.k3s_server.id
  cidr_ipv4         = var.my_ip_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  description       = "SSH admin access"
}

# ══════════════════════════════════════════════════════════════
# 3. SG-K3S-WORKER: INBOUND RULES (CHẶN 100% INTERNET)
# Không có rule nào từ 0.0.0.0/0 – chỉ từ sg-k3s-server
# ══════════════════════════════════════════════════════════════

resource "aws_vpc_security_group_ingress_rule" "worker_vxlan_from_server" {
  security_group_id            = aws_security_group.k3s_worker.id
  referenced_security_group_id = aws_security_group.k3s_server.id # CHAINING
  ip_protocol                  = "udp"
  from_port                    = 8472
  to_port                      = 8472
  description                  = "Flannel VXLAN Overlay ← Server"
}

resource "aws_vpc_security_group_ingress_rule" "worker_kubelet_from_server" {
  security_group_id            = aws_security_group.k3s_worker.id
  referenced_security_group_id = aws_security_group.k3s_server.id # CHAINING
  ip_protocol                  = "tcp"
  from_port                    = 10250
  to_port                      = 10250
  description                  = "Kubelet API – Server exec/logs vào Worker"
}

resource "aws_vpc_security_group_ingress_rule" "worker_nodeport_from_server" {
  security_group_id            = aws_security_group.k3s_worker.id
  referenced_security_group_id = aws_security_group.k3s_server.id # CHAINING
  ip_protocol                  = "tcp"
  from_port                    = 30000
  to_port                      = 32767
  description                  = "Traefik reverse-proxy → NodePort Services on Worker"
}

resource "aws_vpc_security_group_ingress_rule" "worker_node_exporter_self" {
  security_group_id            = aws_security_group.k3s_worker.id
  referenced_security_group_id = aws_security_group.k3s_worker.id # Self-reference
  ip_protocol                  = "tcp"
  from_port                    = 9100
  to_port                      = 9100
  description                  = "Prometheus scrape Node Exporter (nội bộ Worker)"
}

# ══════════════════════════════════════════════════════════════
# 4. SG-RDS: INBOUND – CHỈ DUY NHẤT TỪ SG-K3S-WORKER
# ══════════════════════════════════════════════════════════════

resource "aws_vpc_security_group_ingress_rule" "rds_postgres_from_worker" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.k3s_worker.id # CHAINING – CỨNG
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL 5432 – CHỈ từ K3s Worker (FastAPI Pods)"
}
# Không có rule nào khác → Internet, K3s Server, Harbor đều bị DROP

# ══════════════════════════════════════════════════════════════
# 5. SG-HARBOR: INBOUND RULES
# ══════════════════════════════════════════════════════════════

resource "aws_vpc_security_group_ingress_rule" "harbor_http_public" {
  security_group_id = aws_security_group.harbor.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  description       = "Harbor Web UI HTTP"
}

resource "aws_vpc_security_group_ingress_rule" "harbor_https_public" {
  security_group_id = aws_security_group.harbor.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "Harbor HTTPS – GHA push & public pull"
}

resource "aws_vpc_security_group_ingress_rule" "harbor_https_from_worker" {
  security_group_id            = aws_security_group.harbor.id
  referenced_security_group_id = aws_security_group.k3s_worker.id # CHAINING
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "K3s Worker pull image từ Harbor (nội bộ VPC)"
}

resource "aws_vpc_security_group_ingress_rule" "harbor_https_from_server" {
  security_group_id            = aws_security_group.harbor.id
  referenced_security_group_id = aws_security_group.k3s_server.id # CHAINING
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "K3s Server pull image từ Harbor (nội bộ VPC)"
}

resource "aws_vpc_security_group_ingress_rule" "harbor_node_exporter_from_worker" {
  security_group_id            = aws_security_group.harbor.id
  referenced_security_group_id = aws_security_group.k3s_worker.id # CHAINING
  ip_protocol                  = "tcp"
  from_port                    = 9100
  to_port                      = 9100
  description                  = "Prometheus trên Worker cào Node Exporter của Harbor"
}

resource "aws_vpc_security_group_ingress_rule" "harbor_ssh" {
  security_group_id = aws_security_group.harbor.id
  cidr_ipv4         = var.my_ip_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  description       = "SSH admin access"
}

# ══════════════════════════════════════════════════════════════
# 6. EGRESS RULES (Outbound)
# ══════════════════════════════════════════════════════════════

resource "aws_vpc_security_group_egress_rule" "server_egress_all" {
  security_group_id = aws_security_group.k3s_server.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "All outbound traffic"
}

resource "aws_vpc_security_group_egress_rule" "worker_egress_all" {
  security_group_id = aws_security_group.k3s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Internet egress – tải packages, pull public images"
}

resource "aws_vpc_security_group_egress_rule" "harbor_egress_all" {
  security_group_id = aws_security_group.harbor.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "All outbound – OS updates, Trivy DB download"
}

# sg-rds: Không có egress rule → Drop All (database không cần khởi tạo kết nối ra)
