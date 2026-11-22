# BÁO CÁO TỔNG KẾT PHASE 2 — THÀNH VIÊN 1 (CLOUD INFRASTRUCTURE & PLATFORM)

> **Dự án:** Tự động hóa triển khai ứng dụng 2-Tier theo DevSecOps/GitOps trên AWS  
> **Người thực hiện:** Thành viên 1 — Nguyễn Tấn Quốc (Cloud Infrastructure & Platform Engineer)  
> **Repository quản lý:** `aws-terraform-iac`  
> **Ngày lập:** 22/11/2026  
> **Tài liệu tham chiếu:** `PHASE2.md` v1.0  
> **Trạng thái:** **HOÀN THÀNH TOÀN DIỆN PHASE 2 (GATE 0, GATE 1, GATE 2 PASS)**  

---

## 1. Tóm Tắt Kết Quả Triển Khai Của Thành Viên 1

Trong Phase 2, tôi đã làm chủ và hoàn tất 100% khối lượng công việc hạ tầng và nền tảng bao gồm:

### 1.1. Kiến Trúc Mạng & An Ninh Hạ Tầng (Terraform)
* **S3 Remote State & Native State Locking:** Module `bootstrap/` tạo S3 bucket `devops-lab-tfstate-us-east-1` tích hợp Versioning, mã hóa SSE-S3 (`AES256`), kích hoạt tính năng khóa state không cần DynamoDB (`use_lockfile = true`, Terraform >= 1.11).
* **VPC Hai Tầng (2-Tier Network):** CIDR `10.0.0.0/16` phân tách rõ ràng trên 2 AZs thực tế (`us-east-1a` và `us-east-1b`): 2 Public Subnets và 2 Private DB Subnets. Tiết kiệm chi phí bằng cách không dùng NAT Gateway.
* **Security Group Chaining Nghiêm Ngặt:** 
  - Toàn bộ descriptions chuẩn ASCII.
  - Áp dụng `referenced_security_group_id` cho 4 Security Groups:
    + `sg-k3s-worker`: Chặn 100% Inbound Internet, gỡ bỏ toàn bộ dải NodePort mặc định.
    + `sg-rds`: Chỉ mở duy nhất port 5432 từ `sg-k3s-worker`. Server và Harbor bị DROP.
    + `sg-k3s-server` & `sg-harbor`: Port quản trị SSH (22) và K8s API (6443) chỉ mở cho `my_ip_cidr`.
* **Tài Nguyên EC2 & RDS Thật:**
  - **Harbor:** `t3.medium`, 20GB root gp3, ổ đĩa lưu trữ riêng biệt **EBS 60GB gp3** gắn tại `/dev/xvdf`, gắn Elastic IP tĩnh.
  - **K3s Server:** `t3.medium`, 20GB root gp3, gắn Elastic IP tĩnh.
  - **K3s Worker:** `t3.large`, 30GB root gp3, Public IP egress tải image.
  - **RDS PostgreSQL 16:** `db.t3.micro`, 20GB gp3, `publicly_accessible = false`, DB subnet group 2 AZ.
  - Toàn bộ máy chủ gắn `LabInstanceProfile` của AWS Academy để quản trị SSM.
  - Xóa 100% mock IP/endpoint; bảo vệ `db_password` và các endpoints bằng `sensitive = true`.

### 1.2. Nền Tảng Tự Động Hóa OS & Cụm Kubernetes (Ansible)
* **Dynamic Inventory:** Script `ansible/inventory/generate_inventory.py` sinh file `hosts.ini` từ outputs thật.
* **SSH ProxyJump:** Kết nối vào Worker node nhảy cầu qua K3s Server Bastion, giữ `host_key_checking = True`.
* **6 Roles Hoàn Thiện & Hội Tụ (Idempotent):**
  - `common`: Tắt swap vĩnh viễn, sysctl kernel cho CNI Flannel.
  - `docker`: Docker CE Engine + Compose plugin, log driver giới hạn 50MB chống tràn ổ cứng.
  - `harbor`: Mount 60GB EBS vào `/data`, sinh cert TLS SAN (`hub.<EIP>.nip.io`), cài đặt Harbor v2.10.2 kèm Trivy Scanner, phân phối Root CA.
  - `k3s-server` & `k3s-agent`: Khởi tạo K3s v1.29.5+k3s1 (2 nodes Ready), cấu hình `registries.yaml` tin cậy Root CA của Harbor, ánh xạ DNS nội bộ VPC.
  - `monitoring-agent`: Cài đặt Node Exporter trên port 9100.

---

## 2. Danh Mục Hồ Sơ Bàn Giao (Deliverables)

```text
aws-terraform-iac/
├── bootstrap/                    # Module S3 Remote State + Versioning + SSE
├── terraform/                    # Root module điều phối hạ tầng chính
│   ├── backend.tf                # S3 Native Locking (use_lockfile = true)
│   ├── modules/
│   │   ├── vpc/                  # VPC 10.0.0.0/16, 2 Public + 2 Private DB Subnets
│   │   ├── security/             # Security Group Chaining (ASCII descriptions)
│   │   ├── ec2-harbor/           # Harbor EC2 + 60GB EBS + EIP
│   │   ├── ec2-k3s/              # K3s Server (t3.medium) + Worker (t3.large)
│   │   └── rds/                  # RDS PostgreSQL 16.9 (db.t3.micro, private)
├── ansible/
│   ├── inventory/
│   │   └── generate_inventory.py # Trình sinh inventory động từ Terraform
│   ├── playbooks/01-site.yml     # Playbook điều phối toàn diện
│   └── roles/{common,docker,harbor,k3s-server,k3s-agent,monitoring-agent}/
├── docs/phase2/
│   ├── 00-baseline.md            # Chốt baseline Git & rà soát IaC
│   ├── 01-preflight.md           # Xác minh 6 điều kiện thực tế trên AWS Academy (PASS)
│   ├── adr.md                    # 12 Architectural Decision Records (APPROVED)
│   ├── cost-budget.md            # Dự toán chi phí lab (~$0.19/giờ)
│   ├── 02-state-validation.md    # Báo cáo S3 Remote State & Lockfile
│   ├── 03-network.md             # Sơ đồ mạng VPC & Security Group matrix
│   ├── 04-resources.md           # Báo cáo chi tiết EC2, EBS 60GB, RDS
│   ├── 05-plan-and-apply.md      # Biên bản review Plan & Apply (Gate 1)
│   ├── 06-ansible.md             # Báo cáo Ansible & SSH ProxyJump
│   ├── 07-harbor.md             # Báo cáo Harbor HTTPS Registry
│   ├── 08-k3s.md                # Báo cáo cụm K3s (2 nodes Ready)
│   ├── 10-acceptance.md         # Bảng nghiệm thu E2E Checklist A01-A15 (Gate 2)
│   └── runbook.md               # Quy trình start/stop tiết kiệm chi phí & backup
├── REPORT_PHASE2_TV1.md          # Báo cáo tổng kết Thành viên 1
```

---

## 3. Bàn Giao Đầu Vào Sẵn Sàng Cho Phase 3

Hạ tầng và nền tảng của Thành viên 1 đã sẵn sàng để Thành viên 2 tiếp nhận triển khai tự động hóa CI/CD và GitOps trong Phase 3:
1. **Container Registry:** Harbor HTTPS sẵn sàng tại `https://hub.<HARBOR_EIP>.nip.io`, cấu hình project private `library` kèm robot account để GitHub Actions CI đẩy image.
2. **Kubernetes Cluster:** K3s v1.29.5 (1 Control Plane + 1 Worker) hoạt động ổn định, file `kubeconfig` đã trỏ về Server EIP sẵn sàng kết nối Argo CD.
3. **Database Migration Hook:** Lệnh `alembic upgrade head` chạy thử thủ công thành công trên Worker node, sẵn sàng chuyển đổi thành **Argo CD Sync Wave 1 Hook**.
4. **Bảo mật:** Ma trận Security Group Chaining đã được chứng minh hiệu quả, dữ liệu RDS được bảo vệ cô lập 100%.
