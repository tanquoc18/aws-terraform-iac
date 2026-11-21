# AWS Infrastructure as Code (IaC) & Configuration Management

> **Repository 2**: `aws-terraform-iac`  
> Quản lý toàn bộ hạ tầng đám mây AWS bằng Terraform và cấu hình OS bằng Ansible theo tài liệu thiết kế chuẩn `Plan_DevOps.md`.

---

## 🏗️ Cấu Trúc Repository

```text
aws-terraform-iac/
├── bootstrap/                       # Khởi tạo S3 Remote State Bucket (chạy 1 lần)
│   ├── main.tf
│   └── outputs.tf
├── terraform/                       # Provisioning 100% tài nguyên AWS IaaS
│   ├── backend.tf                   # S3 Native State Locking (use_lockfile = true, TF >= 1.11)
│   ├── providers.tf
│   ├── versions.tf
│   ├── variables.tf
│   ├── terraform.tfvars.example
│   ├── main.tf                      # Điều phối các modules
│   ├── outputs.tf
│   └── modules/
│       ├── vpc/                     # VPC 10.0.0.0/16, 2 Public Subnets, 2 Private DB Subnets, IGW
│       ├── security/                # Security Group Chaining (referenced_security_group_id)
│       ├── ec2-harbor/              # EC2 Harbor + Elastic IP + 60GB gp3 EBS
│       ├── ec2-k3s/                 # EC2 K3s Server (EIP) + EC2 K3s Worker (Public IP)
│       └── rds/                     # Amazon RDS PostgreSQL 16 Single-AZ (Private isolated)
└── ansible/                         # Quản lý cấu hình & phần mềm OS (Không dùng cho IaaS)
    ├── ansible.cfg                  # Strict Host Verification & Pipelining
    ├── inventory/
    │   └── hosts.ini.tpl            # Template sinh inventory từ Terraform outputs
    ├── group_vars/                  # Biến cấu hình cụm và mã hóa Vault
    ├── roles/                       # 6 Ansible Roles chuẩn hóa
    │   ├── common/                  # Tắt swap, sysctl networking, packages cơ bản
    │   ├── docker/                  # Docker CE Engine, compose plugin, log limiting
    │   ├── harbor/                  # Self-signed SAN cert, harbor.yml template, offline install
    │   ├── k3s-server/              # K3s Control plane v1.29.5+k3s1, Traefik Ingress, ServiceLB
    │   ├── k3s-agent/               # K3s Agent kết nối Token, trust Harbor CA
    │   └── monitoring-agent/        # Node Exporter systemd service trên EC2 Harbor
    └── playbooks/
        └── 01-site.yml              # Playbook tổng điều phối
```

---

## 🔒 Mô Hình Bảo Mật Security Group Chaining

- `sg-k3s-server`: Mở HTTP (80) & HTTPS (443) ra Internet (`0.0.0.0/0`) đón traffic vào Traefik Ingress. Mở port 6443 cho `MyIP/32` và `sg-k3s-worker.id`.
- `sg-k3s-worker`: **CHẶN 100% INBOUND TỪ INTERNET (`0.0.0.0/0`)**. Chỉ nhận traffic từ `referenced_security_group_id = sg-k3s-server.id` (Port 8472 UDP Flannel, 10250 TCP Kubelet, NodePort 30000-32767).
- `sg-rds`: **CHỈ NHẬN INBOUND PORT 5432 TỪ `referenced_security_group_id = sg-k3s-worker.id`**. Chặn 100% traffic từ Internet, K3s Server và các thực thể khác.
- `sg-harbor`: Nhận HTTPS 443 từ Internet (GHA Runner push image) và từ `sg-k3s-worker.id` / `sg-k3s-server.id` nội bộ VPC; nhận port 9100 cào metrics từ `sg-k3s-worker.id`.

---

## 🚀 Hướng Dẫn Sử Dụng Sơ Bộ (Phase 2 Sẵn Sàng)

### 1. Khởi tạo S3 Remote State Bucket
```bash
cd bootstrap
terraform init
terraform apply
```

### 2. Triển khai Hạ tầng AWS
```bash
cd ../terraform
cp terraform.tfvars.example terraform.tfvars
# Điền IP cá nhân (my_ip_cidr) và mật khẩu RDS vào terraform.tfvars
terraform init
terraform plan
terraform apply
```

### 3. Cấu hình OS với Ansible
```bash
cd ../ansible
# Sinh inventory từ Terraform outputs
ansible-playbook -i inventory/hosts.ini playbooks/01-site.yml
```
