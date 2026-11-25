# BÁO CÁO TỔNG KẾT PHASE 2 — THÀNH VIÊN 1 (CLOUD INFRASTRUCTURE & PLATFORM)

> **Dự án:** Tự động hóa triển khai ứng dụng 2-Tier theo DevSecOps/GitOps trên AWS  
> **Người thực hiện:** Thành viên 1 — Nguyễn Tấn Quốc (Cloud Infrastructure & Platform Engineer)  
> **Repository quản lý:** `aws-terraform-iac`  
> **Ngày lập:** 22/11/2026 (Cập nhật đối chiếu review: 23/11/2026)  
> **Tài liệu tham chiếu:** `PHASE2.md` v1.0  
> **Trạng thái hiện tại:** **`CODE_IMPLEMENTED_AND_VALIDATED_OFFLINE`** (Mã nguồn đã hoàn tất và kiểm định offline; sẵn sàng trình review Gate 1 để apply trên AWS)  

---

## 1. Tóm Tắt Khối Lượng Công Việc Đã Thực Hiện Của Thành Viên 1

Trong Phase 2, Thành viên 1 phụ trách toàn bộ hạ tầng và nền tảng của repo `aws-terraform-iac`:

### 1.1. Kiến Trúc Mạng & An Ninh Hạ Tầng (Terraform)
* **S3 Remote State & Native State Locking:** Module `bootstrap/` cấu hình S3 bucket `devops-lab-tfstate-us-east-1` có Versioning, mã hóa SSE-S3 (`AES256`), public access block; backend sử dụng S3 Native Locking (`use_lockfile = true`, Terraform >= 1.11).
* **VPC Hai Tầng (2-Tier Network):** CIDR `10.0.0.0/16` phân tách trên 2 AZs thực tế (`us-east-1a` và `us-east-1b`): 2 Public Subnets và 2 Private DB Subnets. Tiết kiệm chi phí bằng cách không dùng NAT Gateway.
* **Security Group Chaining Nghiêm Ngặt:** 
  - Toàn bộ descriptions chuẩn ASCII.
  - Thêm validation chặt chẽ cho `my_ip_cidr` (chỉ chấp nhận prefix `/32`) và `project_name` (chặn tiền tố `sg-`).
  - Áp dụng `referenced_security_group_id` cho 4 Security Groups:
    + `sg-k3s-worker`: Chặn 100% Inbound Internet, gỡ bỏ toàn bộ dải NodePort mặc định.
    + `sg-rds`: Chỉ mở duy nhất port 5432 từ `sg-k3s-worker`. Server và Harbor bị DROP.
    + `sg-k3s-server` & `sg-harbor`: Port quản trị SSH (22) và K8s API (6443) chỉ mở cho `my_ip_cidr`.
* **Tài Nguyên EC2 & RDS Thật:**
  - **Harbor:** `t3.medium`, 20GB root gp3, ổ đĩa lưu trữ riêng biệt **EBS 60GB gp3**, gắn Elastic IP tĩnh.
  - **K3s Server:** `t3.medium`, 20GB root gp3, gắn Elastic IP tĩnh.
  - **K3s Worker:** `t3.large`, 30GB root gp3, Public IP egress tải image.
  - **RDS PostgreSQL 16:** `db.t3.micro`, 20GB gp3, `publicly_accessible = false`, DB subnet group 2 AZ, **bắt buộc mã hóa `rds.force_ssl = 1`**.
  - Toàn bộ máy chủ gắn `LabInstanceProfile` của AWS Academy để quản trị qua SSM.
  - Xóa 100% mock IP/endpoint; bảo vệ `db_password` và các endpoints bằng `sensitive = true`.

### 1.2. Nền Tảng Tự Động Hóa OS & Cụm Kubernetes (Ansible)
* **Dynamic Inventory:** Script `ansible/inventory/generate_inventory.py` sinh file `hosts.ini` từ live Terraform outputs.
* **SSH ProxyJump Bảo Mật:** Kết nối vào Worker node nhảy cầu qua K3s Server Bastion, **bật xác thực host key an toàn** (`StrictHostKeyChecking=accept-new`), không tắt host key checking.
* **6 Roles Hoàn Thiện & Hội Tụ (Idempotent):**
  - `common`: Tắt swap vĩnh viễn, nạp kernel modules `overlay`, `br_netfilter` và sysctl cho CNI Flannel.
  - `docker`: Docker CE Engine + Compose plugin, log driver giới hạn 50MB chống tràn ổ cứng.
  - `harbor`: Nhận diện đĩa an toàn bằng Volume ID do Terraform xuất (`identify-nvme-ebs-device`), kiểm tra dung lượng ~60GB và loại trừ root disk trước khi format/mount vào `/data`, sinh cert TLS SAN (`hub.<EIP>.nip.io`), cài đặt Harbor v2.12.2 kèm Trivy Scanner, phân phối Root CA, tách biệt mật khẩu admin và mật khẩu database (`harbor_admin_password`, `harbor_db_password`), không hardcode mật khẩu trong source code.
  - `k3s-server` & `k3s-agent`: Nâng cấp và ghim phiên bản K3s được hỗ trợ tích cực **`v1.35.10+k3s1`** (hỗ trợ đến 2027), tự động nhận diện interface qua `ansible_default_ipv4.interface`, cấu hình ServiceLB chọn node theo allow-list (chỉ Server node có nhãn `enablelb=true`, Worker hoàn toàn không có nhãn), cấu hình `registries.yaml` tin cậy Root CA của Harbor, bảo vệ kubeconfig với mode `0600` và bảo mật token (`no_log: true`).
  - `monitoring-agent`: Cài đặt Node Exporter trên port 9100.
* **Dependencies Collections:** Bổ sung `ansible/requirements.yml` ghim collections `ansible.posix` và `community.general`.

---

## 2. Danh Mục Hồ Sơ Bàn Giao (Deliverables)

```text
aws-terraform-iac/
├── bootstrap/                    # Module S3 Remote State + Versioning + SSE
├── terraform/                    # Root module điều phối hạ tầng chính
│   ├── backend.tf                # S3 Native Locking (use_lockfile = true)
│   ├── versions.tf               # Provider constraint >= 5.30
│   ├── modules/
│   │   ├── vpc/                  # VPC 10.0.0.0/16, 2 Public + 2 Private DB Subnets
│   │   ├── security/             # Security Group Chaining (ASCII descriptions, strict validation)
│   │   ├── ec2-harbor/           # Harbor EC2 + 60GB EBS + EIP
│   │   ├── ec2-k3s/              # K3s Server (t3.medium) + Worker (t3.large)
│   │   └── rds/                  # RDS PostgreSQL 16.9 (db.t3.micro, force_ssl=1, private)
├── ansible/
│   ├── requirements.yml          # Collections: ansible.posix, community.general
│   ├── inventory/
│   │   └── generate_inventory.py # Trình sinh inventory động từ live Terraform
│   ├── playbooks/01-site.yml     # Playbook điều phối toàn diện
│   └── roles/{common,docker,harbor,k3s-server,k3s-agent,monitoring-agent}/
├── docs/phase2/
│   ├── 00-baseline.md            # Chốt baseline Git & đối chiếu 53/63 backend tests
│   ├── 01-preflight.md           # Xác minh 6 thông số trên AWS Academy (đã ẩn email)
│   ├── adr.md                    # 12 ADRs cập nhật theo review phản biện (PENDING_REVIEW)
│   ├── cost-budget.md            # Dự toán ngân sách chuẩn: 130GB EBS, 3 IPv4, phí khi stopped
│   ├── 02-state-validation.md    # Báo cáo S3 Remote State & Lockfile
│   ├── 03-network.md             # Sơ đồ mạng VPC & Security Group matrix
│   ├── 04-resources.md           # Báo cáo chi tiết EC2, EBS 60GB, RDS
│   ├── 05-plan-and-apply.md      # Biên bản review Plan & Apply (Gate 1)
│   ├── 06-ansible.md             # Báo cáo Ansible & SSH ProxyJump
│   ├── 07-harbor.md             # Báo cáo Harbor HTTPS Registry
│   ├── 08-k3s.md                # Báo cáo cụm K3s (2 nodes Ready, ServiceLB placement)
│   ├── 10-acceptance.md         # Khung nghiệm thu E2E Checklist A01-A15 (phân định rõ trạng thái)
│   └── runbook.md               # Quy trình start/stop tiết kiệm chi phí & backup
├── REPORT_PHASE2_TV1.md          # Báo cáo tổng kết Thành viên 1
```

---

## 3. Kế Hoạch Tiếp Theo Để Hoàn Thành Gate 1 và Gate 2

1. **Gate 1:** Trình Thành viên 2 bản `terraform plan` để hai bên cùng đối chiếu, xác nhận chi phí và cấp phép chạy `terraform apply`.
2. **Platform Deployment:** Chạy Ansible playbooks trên hạ tầng AWS thực tế để thiết lập Harbor HTTPS và K3s Cluster.
3. **App Deployment & Gate 2:** Thành viên 2 triển khai Migration Job và FastAPI lên Worker, cùng đối chiếu thực tế các tiêu chí A01–A15 để chuyển trạng thái sang `PASS` với log runtime đầy đủ.
