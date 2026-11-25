# Hướng dẫn làm việc cho Coding Agent (Codex / Claude Code / Copilot) — Thành viên 1

> **Dự án:** Tự động hóa triển khai ứng dụng 2-Tier theo chuẩn DevSecOps & GitOps trên AWS  
> **Repository:** `tanquoc18/aws-terraform-iac` (Local: `d:\DevOps\aws-terraform-iac`)  
> **Vai trò của Agent:** **Thành viên 1 (TV1) — Cloud Infrastructure & Platform Engineer**  
> **Thành viên phối hợp:** Thành viên 2 (TV2 - Cao Sang / CaoSangg, repo `python-app-backend` phụ trách App & Workload)  
> **Tài liệu nguồn chân lý (Single Source of Truth):** `d:\DevOps\kịch bản\PHASE2.md` và `docs/phase2/`

---

## 1. Nguyên Tắc & Phạm Vi Hoạt Động Của Agent

1. **Phân định trách nhiệm:**
   - **TV1 (Agent):** Quản lý toàn bộ hạ tầng AWS qua Terraform (`bootstrap/`, `terraform/`), tự động hóa cấu hình hệ điều hành qua Ansible (`ansible/`), xây dựng Private Registry Harbor HTTPS (`hub.<HARBOR_EIP>.nip.io`), dựng cụm K3s Cluster 2-node (Server + Worker), cơ sở dữ liệu RDS PostgreSQL 16 riêng biệt và hồ sơ nghiệm thu Gate 0, Gate 1, Gate 2.
   - **TV2 (Cao Sang):** Phụ trách backend FastAPI, migration Alembic, đóng gói Docker images, push image lên Harbor, viết manifests Kubernetes (`song-api`, Migration Job `song-migrate-<release-id>`), và triển khai ứng dụng lên Worker node.
2. **Quy tắc an toàn & bảo mật:**
   - **TUYỆT ĐỐI KHÔNG tự ý chạy `terraform apply` hoặc tạo tài nguyên AWS có phát sinh chi phí** khi chưa có lệnh rõ ràng từ người dùng và sự đồng thuận Gate 1 từ TV2.
   - **TUYỆT ĐỐI KHÔNG commit file chứa bí mật**, mật khẩu plaintext, token K3s, file `*.pem`, `*.key`, hay file trạng thái `.tfstate` lên Git.
   - Luôn chạy kiểm tra offline (`terraform fmt -check`, `terraform validate`, PyYAML check, Python syntax check) trước khi commit.
   - Luôn giữ branch làm việc sạch (`git status`), commit có message rõ ràng theo chuẩn Conventional Commits.

---

## 2. Hiện Trạng Dự Án (Tính Đến 25/11/2026)

- **Nhánh Gate 0 (`feature/phase2-gate0`):** Đã commit `1f77c0b` và push lên remote. Toàn bộ 4 tài liệu Gate 0 (`00-baseline.md`, `01-preflight.md`, `adr.md`, `cost-budget.md`) đã được cập nhật chuẩn xác.
- **Nhánh IaC Implementation (`feature/phase2-iac-implementation`):**
  - Đã mở **Pull Request #2:** `https://github.com/tanquoc18/aws-terraform-iac/pull/2`.
  - Đã giải quyết 100% các lỗi phản biện từ TV2:
    + **H1 & H2:** Task nhận diện EBS Harbor có `args.executable: /bin/bash`, chuyển `tr -d '-'` chuẩn POSIX, xóa bỏ hoàn toàn fallback không xác minh, fail-closed an toàn theo AWS `identify-nvme-ebs-device`.
    + **H3:** Script `generate_inventory.py` có `sys.exit(1)`, validate đầy đủ các output bắt buộc, ghi file atomic write, có bộ unit test `ansible/inventory/test_generate_inventory.py` (3/3 tests PASS).
    + **H4:** Cài K3s agent có cờ gán nhãn `--node-label node-role.kubernetes.io/worker=worker`, khớp `nodeSelector` manifest TV2.
    + **H5:** Nâng cấp Harbor lên bản `v2.12.2` (release được hỗ trợ tích cực) kèm mã băm SHA256.
    + **M1 & M2:** Nâng patch K3s lên `v1.35.10+k3s1`; Worker không gắn nhãn `enablelb` để ServiceLB allow-list chỉ chọn Server.
    + **M3 & M4:** Guard check-mode (`ansible_check_mode`) cho toàn bộ chuỗi task EBS; backup SQLite dùng snapshot online; ghim phiên bản chính xác cho Collections trong `ansible/requirements.yml` (`ansible.posix: 1.5.4`, `community.general: 9.5.1`).
  - Commit mới nhất: **`17ae992`**.
  - **Trạng thái hiện tại:** Đang chờ TV2 (Sang) review và bấm **Approve** PR #2.

---

## 3. Kiến Trúc Hạ Tầng & Công Nghệ Được Phê Duyệt

1. **VPC 2-Tier (`10.0.0.0/16`) trên 2 AZs (`us-east-1a`, `us-east-1b`):**
   - 2 Public Subnets: Subnet 1 (`10.0.1.0/24`) chứa K3s Server & Worker; Subnet 2 (`10.0.2.0/24`) chứa Harbor.
   - 2 Private DB Subnets (`10.0.11.0/24`, `10.0.12.0/24`) chứa RDS DB Subnet Group.
   - Không dùng NAT Gateway để tiết kiệm ngân sách.
2. **Security Groups Chaining:**
   - `sg-k3s-worker`: Chặn 100% Inbound Internet `0.0.0.0/0`. Chỉ cho phép SSH (22) từ K3s Server SG và K8s node traffic.
   - `sg-rds`: Chỉ mở cổng 5432 duy nhất từ `sg-k3s-worker`. Server và Harbor bị drop.
   - `sg-k3s-server` & `sg-harbor`: Port 22 (SSH) và Port 6443 (K8s API) chỉ mở cho `var.my_ip_cidr` (`/32`).
3. **Compute & Storage (130GB EBS gp3 tổng cộng):**
   - EC2 Harbor: `t3.medium`, 20GB root gp3 + **60GB data volume gp3** mount `/data`, gán Elastic IP.
   - EC2 K3s Server: `t3.medium`, 20GB root gp3, gán Elastic IP.
   - EC2 K3s Worker: `t3.large`, 30GB root gp3, public IPv4 tự động (egress).
   - RDS PostgreSQL 16: `db.t3.micro`, 20GB gp3, `publicly_accessible = false`, `rds.force_ssl = 1`.
4. **Ansible & K3s:**
   - K3s version: `v1.35.10+k3s1`.
   - Worker quản trị qua SSH ProxyJump qua Server: `-o ProxyJump=ubuntu@<SERVER_EIP> -o StrictHostKeyChecking=accept-new`.
   - Harbor registry: `hub.<HARBOR_EIP>.nip.io`, self-signed Root CA tại `/data/cert/ca.crt` phân phối vào system trust store và `/etc/rancher/k3s/registries.yaml`.

---

## 4. Các Bước Tiếp Theo Cần Làm (Khi Được Phê Duyệt Triển Khai AWS)

Khi người dùng và TV2 đã duyệt PR #2 và sẵn sàng bắt đầu phiên thực hành trên AWS Academy:

### Bước 1: Khởi động phiên AWS Academy
- Người dùng bấm **"Start Lab"** trên AWS Academy Learner Lab và chờ đèn xanh.
- Cập nhật AWS Credentials tạm thời vào `~/.aws/credentials` (AWS CLI).

### Bước 2: Tạo S3 State Bucket (P2-02 Bootstrap)
```powershell
Set-Location "d:\DevOps\aws-terraform-iac\bootstrap"
terraform init
terraform apply -auto-approve
```

### Bước 3: Triển khai Hạ tầng AWS chính (P2-03, P2-04, P2-05 Gate 1)
```powershell
Set-Location "d:\DevOps\aws-terraform-iac\terraform"
# Copy file biến mẫu
Copy-Item terraform.tfvars.example terraform.tfvars
# Cập nhật my_ip_cidr (địa chỉ IP công cộng của người dùng dạng x.x.x.x/32)
# Cập nhật db_password an toàn
terraform init
terraform plan -out=tfplan
# Review kỹ plan cùng TV2 trước khi apply
terraform apply tfplan
```

### Bước 4: Tự động sinh Inventory và chạy cấu hình Ansible (P2-06, P2-07, P2-08)
```powershell
Set-Location "d:\DevOps\aws-terraform-iac"
python ansible/inventory/generate_inventory.py

# Cài đặt requirements collections
ansible-galaxy collection install -r ansible/requirements.yml

# Thực thi cấu hình hệ thống
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/01-site.yml `
  -e "harbor_admin_password=<SECURE_ADMIN_PASS>" `
  -e "harbor_db_password=<SECURE_DB_PASS>"
```

### Bước 5: Bàn giao cho TV2 để triển khai Workload (P2-09)
Bàn giao các thông số cho TV2:
1. Harbor Domain: `hub.<HARBOR_EIP>.nip.io`
2. Harbor CA file: `/tmp/harbor_ca.crt`
3. Harbor User / Password (đã tạo)
4. Worker node label: `node-role.kubernetes.io/worker=worker`
5. Kubeconfig: `/tmp/kubeconfig`
6. RDS Private Hostname & Port: `<RDS_ENDPOINT>`

### Bước 6: Nghiệm thu Gate 2 (P2-10)
Kiểm tra và điền bằng chứng thực tế cho 15 tiêu chí (A01–A15) trong `docs/phase2/10-acceptance.md`:
- Pods `song-api` chạy Ready trên Worker node.
- Ingress Traefik route traffic vào `song-api`.
- Probes `/health/live` và `/health/ready` trả về HTTP 200.
- CRUD `/songs` lưu dữ liệu bền vững vào RDS PostgreSQL 16.
- Rollout restart Pod, dữ liệu `/songs` vẫn còn nguyên vẹn.

### Bước 7: Dọn dẹp & Tiết kiệm chi phí (P2-11 Runbook)
- Hết buổi làm việc: Tắt 3 EC2 instances và RDS database theo hướng dẫn trong `docs/phase2/runbook.md` để bảo vệ ngân sách $100.
- Kết thúc môn học: Chạy `terraform destroy` có kiểm soát.

---

## 5. Quy Định Báo Cáo Của Agent

Sau mỗi phiên làm việc hoặc hoàn thành một work package `P2-xx`, Agent bắt buộc xuất báo cáo gồm 4 mục:
1. **Files changed:** Danh sách file và tóm tắt thay đổi.
2. **Kết quả kiểm thử:** Các lệnh đã chạy và kết quả cụ thể (log, exit code).
3. **Dependency còn thiếu:** Những việc đang chờ từ TV2 hoặc AWS.
4. **Trạng thái:** Một trong các trạng thái `PASS`, `PARTIAL`, `BLOCKED`, hoặc `NOT VERIFIED`.
