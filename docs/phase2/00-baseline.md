# P2-00 — CHỐT BASELINE PHASE 1 VÀ HIỆN TRẠNG REPOSITORY

> **Dự án:** Tự động hóa triển khai ứng dụng 2-Tier theo DevSecOps/GitOps trên AWS  
> **Thực hiện:** Thành viên 1 (Cloud Infrastructure & Platform Engineer)  
> **Ngày lập:** 22/11/2026  
> **Tài liệu tham chiếu:** `PHASE2.md` v1.0, Work Package P2-00  

---

## 1. Trạng thái Repository và Baseline Git

### 1.1. Repository IaC: `aws-terraform-iac`
* **URL:** `https://github.com/tanquoc18/aws-terraform-iac.git`
* **Trạng thái PR sửa lỗi Phase 1:** PR #1 (`fix/phase1-iac-validation`) tại commit `609f5d0` **ĐÃ ĐƯỢC MERGE** vào nhánh `main`.
* **Merge Commit SHA trên `main`:** `92f397a3d4b8c35337f40396fa775185fed0ccbc`
* **Người merge / review:** Cao Sang Lê (Thành viên 2) lúc 21:06:24 ngày 22/11/2026.
* **Nhánh làm việc Phase 2:** `feature/phase2-gate0` (tách từ `main` commit `92f397a`).

### 1.2. Repository Backend: `python-app-backend`
* **Trạng thái:** Hoàn tất Phase 1 hardening.
* **Kết quả kiểm thử:** 53/53 tests pass (100% core endpoints CRUD `/songs`, `/health/live`, `/health/ready`).
* **Cơ chế an toàn:** DB Isolation (tách riêng `songs_test_db` và `songs_db`), migration head `750af730f01c` (Alembic), non-root container user (`appuser:10001`).

---

## 2. Rà soát Hiện trạng Mã nguồn IaC & Ansible

| Thành phần | Đường dẫn | Trạng thái kỹ thuật | Khoảng trống cần hoàn thiện ở Phase 2 |
|---|---|---|---|
| **S3 Bootstrap** | `bootstrap/` | `PASS` (Validate đạt) | Đã sẵn sàng chạy 1 lần duy nhất để tạo bucket state S3 có versioning + SSE. |
| **Terraform Backend** | `terraform/backend.tf` | `PASS` (Cú pháp hợp lệ) | Đã cấu hình S3 native lockfile (`use_lockfile = true`), chưa khởi tạo kết nối backend thật do chờ S3 bucket từ bootstrap. |
| **VPC Module** | `terraform/modules/vpc` | `PASS` (Validate đạt) | Đã có VPC `10.0.0.0/16`, 2 Public Subnets, 2 Private DB Subnets, IGW và Route Tables. Cần rà soát mapping AZ thực tế của account. |
| **Security Module** | `terraform/modules/security` | `PASS` (Validate đạt) | Đã sửa naming chuẩn AWS (loại bỏ tiền tố `sg-`), áp dụng Security Group Chaining nghiêm ngặt (RDS chỉ nhận 5432 từ Worker). |
| **EC2 Harbor Module** | `terraform/modules/ec2-harbor` | `PARTIAL` (Skeleton) | Mới chỉ khai báo Elastic IP (`aws_eip.harbor`). **Thiếu:** `aws_instance` (Harbor t3.medium), cấu hình ổ cứng gắn ngoài EBS 60GB gp3, `user_data`. |
| **EC2 K3s Module** | `terraform/modules/ec2-k3s` | `PARTIAL` (Skeleton) | Mới chỉ khai báo Elastic IP cho Server và placeholder IP cho Worker. **Thiếu:** `aws_instance` Server (t3.medium) và Worker (t3.large). |
| **RDS Module** | `terraform/modules/rds` | `PARTIAL` (Skeleton/Mock) | Mới chỉ có khai báo biến và output mock. **Thiếu:** `aws_db_subnet_group`, `aws_db_parameter_group`, `aws_db_instance` (PostgreSQL 16). |
| **Ansible Common Role** | `ansible/roles/common` | `PARTIAL` (Một phần) | Đã có task tắt swap và bật sysctl `net.ipv4.ip_forward`. **Thiếu:** cấu hình timezone, cập nhật packages cơ bản. |
| **Ansible Docker Role** | `ansible/roles/docker` | `PARTIAL` (Một phần) | Đã có task cài gói bổ trợ. **Thiếu:** cài đặt Docker CE Engine, Compose plugin, cấu hình `/etc/docker/daemon.json`. |
| **Ansible Harbor Role** | `ansible/roles/harbor` | `PARTIAL` (Placeholder) | 100% task đang là `ansible.builtin.debug`. Cần viết kịch bản sinh TLS self-signed, giải nén offline installer, chạy setup. |
| **Ansible K3s Roles** | `ansible/roles/k3s-server`, `k3s-agent` | `PARTIAL` (Placeholder) | 100% task đang là `ansible.builtin.debug`. Cần viết kịch bản cài đặt cụm, cấu hình registries.yaml trust Harbor CA. |
| **Ansible Monitoring** | `ansible/roles/monitoring-agent` | `PARTIAL` (Placeholder) | 100% task đang là `ansible.builtin.debug`. Cần viết cài đặt node_exporter systemd service. |

---

## 3. Kết luận Baseline Gate 0 (P2-00)

* [x] Đã đối chiếu và merge PR `fix/phase1-iac-validation` vào nhánh `main` (`92f397a`).
* [x] Toàn bộ code Terraform root và bootstrap vượt qua `terraform fmt -check` và `terraform validate`.
* [x] Xác định rõ ràng các phần Skeleton cần hoàn thiện ở P2-02, P2-03, P2-04 và P2-06.
* [x] **Cam kết:** Giữ vững nguyên tắc không tự nhận việc đã deploy AWS; không có file chứa bí mật hoặc `.tfstate` được commit lên Git.
