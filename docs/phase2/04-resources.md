# P2-04 — BÁO CÁO HOÀN THIỆN TÀI NGUYÊN EC2, RDS VÀ OUTPUTS THẬT

> **Dự án:** Tự động hóa triển khai ứng dụng 2-Tier theo DevSecOps/GitOps trên AWS  
> **Thực hiện:** Thành viên 1 (Cloud Infrastructure & Platform Engineer)  
> **Ngày lập:** 22/11/2026  
> **Tài liệu tham chiếu:** `PHASE2.md` v1.0, Work Package P2-04  
> **Trạng thái kiểm định:** `PASS` (Đã thay thế 100% skeleton bằng tài nguyên thật, validate đạt chuẩn)  

---

## 1. Chi Tiết Các Tài Nguyên Đã Hoàn Thiện

### 1.1. Module EC2 Harbor Registry (`modules/ec2-harbor`)
- **AMI:** Ubuntu 22.04 LTS amd64 chính thức từ Canonical (`099720109477`).
- **Cấu hình phần cứng:** `t3.medium` (2 vCPU, 4GB RAM) đặt tại Public Subnet 2.
- **Ổ đĩa hệ thống:** 20GB gp3 (`aws_instance.harbor.root_block_device`).
- **Ổ đĩa dữ liệu chuyên dụng:** **60GB EBS gp3** riêng biệt (`aws_ebs_volume.harbor_data`) gắn tại `/dev/xvdf` để lưu trữ dữ liệu Docker images và database của Harbor.
- **Địa chỉ IP:** Elastic IP tĩnh (`aws_eip.harbor`) được gắn trực tiếp qua `aws_eip_association`.
- **IAM Instance Profile:** Gắn `LabInstanceProfile` (đã xác thực tồn tại ở Gate 0) để sẵn sàng kết nối qua AWS SSM.

### 1.2. Module K3s Cluster (`modules/ec2-k3s`)
- **AMI:** Ubuntu 22.04 LTS amd64.
- **K3s Control Plane Server:**
  + Instance type: `t3.medium` (2 vCPU, 4GB RAM) tại Public Subnet 1.
  + Ổ cứng: 20GB gp3 root.
  + Elastic IP: Được cấp phát EIP tĩnh (`aws_eip.k3s_server`) để làm domain Traefik Ingress và Kubeconfig endpoint ổn định.
  + IAM: Gắn `LabInstanceProfile`.
- **K3s Worker Node:**
  + Instance type: `t3.large` (2 vCPU, 8GB RAM) tại Public Subnet 1 (đủ tài nguyên chạy đồng thời FastAPI Pods, Alembic Job, ArgoCD và Monitoring).
  + Ổ cứng: 30GB gp3 root.
  + Mạng: Gắn Public IP tự động cho egress tải packages/ảnh; inbound bị Security Group chặn 100%.
  + IAM: Gắn `LabInstanceProfile`.

### 1.3. Module RDS PostgreSQL 16 (`modules/rds`)
- **Engine & Version:** PostgreSQL `16.9` (hỗ trợ chính thức trên AWS us-east-1).
- **Instance Class:** `db.t3.micro` (tối ưu chi phí lab).
- **Lưu trữ:** 20GB gp3 (có tính năng autoscaling tối đa 50GB).
- **Phân vùng mạng:**
  + `aws_db_subnet_group`: Tạo nhóm subnet bao phủ cả 2 Private DB Subnets (`us-east-1a` và `us-east-1b`).
  + `publicly_accessible = false` (Cô lập hoàn toàn khỏi Internet).
  + `vpc_security_group_ids = [module.security.sg_rds_id]` (Chỉ chấp nhận duy nhất port 5432 từ K3s Worker).
- **Parameter Group:** `postgres16` với cấu hình an toàn cho môi trường lab.
- **Thiết lập an toàn:** `skip_final_snapshot = true` và `deletion_protection = false` cho phép dọn dẹp sạch sẽ sau khi kết thúc phiên lab.

---

## 2. Xóa Bỏ Hoàn Toàn Placeholder và Chuẩn Hóa Outputs Thật

Toàn bộ các giá trị giả lập (mock IP `10.0.1.50`, mock RDS endpoint `mock-rds-endpoint...`) đã được **xóa bỏ 100%**.

Tất cả outputs tại [terraform/outputs.tf](file:///d:/DevOps/aws-terraform-iac/terraform/outputs.tf) hiện trỏ trực tiếp vào thuộc tính của tài nguyên AWS thật:

| Output Name | Nguồn tham chiếu thực tế | Thuộc tính bảo mật | Mục đích sử dụng |
|---|---|---|---|
| `vpc_id` | `module.vpc.vpc_id` | Public | Định danh VPC |
| `harbor_public_ip` | `module.ec2_harbor.elastic_ip` | Public | Domain nip.io cho Harbor registry |
| `harbor_private_ip` | `module.ec2_harbor.private_ip` | Internal | Kéo image nội bộ VPC |
| `k3s_server_public_ip` | `module.ec2_k3s.server_elastic_ip` | Public | Kubeconfig & API Ingress |
| `k3s_server_private_ip` | `module.ec2_k3s.server_private_ip` | Internal | K3s Agent kết nối về Server API |
| `k3s_worker_public_ip` | `module.ec2_k3s.worker_public_ip` | Public | Egress IP |
| `k3s_worker_private_ip` | `module.ec2_k3s.worker_private_ip` | Internal | Giao tiếp nội bộ cụm K8s |
| `rds_endpoint` | `module.rds.db_endpoint` | `sensitive = true` | Endpoint DSN cho FastAPI & Alembic |
| `rds_address` | `module.rds.db_address` | `sensitive = true` | Hostname RDS cho K8s ConfigMap |
| `rds_port` | `module.rds.db_port` | Public | Port 5432 |
| `sg_ids` | `module.security.sg_ids` | Public | Danh sách SG IDs cho Ansible inventory |

---

## 3. Bảo Mật Bí Mật (Secrets Management)
- Biến `db_password` được đánh dấu `sensitive = true` ở cả module con và root module.
- Các outputs liên quan đến địa chỉ RDS (`rds_endpoint`, `rds_address`) được bảo vệ bằng `sensitive = true` để không bị in plaintext ra console hay log CI.
- Mật khẩu chỉ được truyền qua biến môi trường hoặc file `terraform.tfvars` (đã nằm trong `.gitignore`, không bao giờ commit lên GitHub).
