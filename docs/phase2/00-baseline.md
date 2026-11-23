# P2-00 — CHỐT BASELINE PHASE 1 VÀ HIỆN TRẠNG REPOSITORY

> **Dự án:** Tự động hóa triển khai ứng dụng 2-Tier theo DevSecOps/GitOps trên AWS  
> **Thực hiện:** Thành viên 1 (Cloud Infrastructure & Platform Engineer)  
> **Ngày lập:** 22/11/2026 (Cập nhật đối chiếu review: 23/11/2026)  
> **Tài liệu tham chiếu:** `PHASE2.md` v1.0, Work Package P2-00  

---

## 1. Trạng thái Repository và Baseline Git

### 1.1. Repository IaC: `aws-terraform-iac`
* **URL:** `https://github.com/tanquoc18/aws-terraform-iac.git`
* **Trạng thái PR sửa lỗi Phase 1:** PR #1 (`fix/phase1-iac-validation`) tại commit `609f5d0` **ĐÃ MERGE** vào nhánh `main`.
* **Merge Commit SHA trên `main`:** `92f397a3d4b8c35337f40396fa775185fed0ccbc`
* **Người merge / review:** Cao Sang Lê (Thành viên 2) lúc 21:06:24 ngày 22/11/2026.
* **Nhánh làm việc Gate 0:** `feature/phase2-gate0` (tách từ `main` commit `92f397a`).

### 1.2. Repository Backend: `python-app-backend`
* **URL:** `https://github.com/CaoSangg/python-app-backend.git`
* **Nhánh làm việc chính thức:** `main` (và nhánh chuẩn bị `feature/phase2-app-preparation` của TV2).
* **Commit SHA baseline hiện tại trên `main`:** `91df667ec1ad8e877b5a1cab51f1025a3891e515` (`91df667`).
* **Trạng thái Release Hardening:** PR #3 (`chore/phase1-check`) đã **MERGE** vào `main` tại commit `901fe18`. Commit `c2a3b97` là ancestor của baseline. Diff từ merge PR #3 tới baseline rỗng cho `project/`, `docker-compose.yml` và `.env.example`.
* **Trạng thái Release Tag (`v1.0.0-phase1`):** **`PENDING`** (Chưa thấy tag trên remote, baseline theo commit SHA `91df667` đã xác minh).
* **Kết quả kiểm thử & Hardening tại SHA `91df667`:**
  - **Bộ kiểm thử chính thức: 63/63 tests PASS** trên Python 3.12 gồm 42 unit API tests, 10 database isolation guards, và 11 integration tests (với `docker compose --profile test run --rm --build -T test`).
  - **Test coverage trên module `app` đạt 100%** (bao gồm branch coverage).
  - Tách biệt database môi trường: service `db_test` riêng (`songs_test_db`), có Safety Guard trong `test_songs_api.py` và `test_database_isolation.py` từ chối chạy trên database ứng dụng (`songs_db`).
  - Container an toàn: Multi-stage build, Non-root user `appuser:10001`, Alembic migration single head `750af730f01c`.
* **Bằng chứng Persistence:**
  - Dữ liệu PostgreSQL được lưu trữ bền vững qua Docker named volume `postgres_data` gắn vào `/var/lib/postgresql/data`.
  - Khởi động lại container (`docker compose down` rồi `docker compose up`) dữ liệu bảng `song` vẫn được bảo tồn nguyên vẹn.
---

## 2. Rà Soát Hiện Trạng Mã Nguồn IaC & Ansible (Khoảng Trống Cần Làm)

| Thành phần | Đường dẫn | Trạng thái kỹ thuật | Khoảng trống cần hoàn thiện ở Phase 2 |
|---|---|---|---|
| **S3 Bootstrap** | `bootstrap/` | `PASS` (Validate đạt) | Cần chạy tạo bucket thật ở P2-02 sau khi Gate 0 được phê duyệt. |
| **Terraform Backend** | `terraform/backend.tf` | `PASS` (Cú pháp hợp lệ) | Cấu hình S3 native lockfile (`use_lockfile = true`), chờ kết nối S3 backend thật. |
| **VPC Module** | `terraform/modules/vpc` | `PASS` (Validate đạt) | Đã có VPC `10.0.0.0/16`, 2 Public Subnets, 2 Private DB Subnets, IGW và Route Tables. Cần tham số hóa mapping AZ từ biến `availability_zones`. |
| **Security Module** | `terraform/modules/security` | `PASS` (Validate đạt) | Cần chuẩn hóa toàn bộ description sang ASCII, thêm validation cho `project_name` và `my_ip_cidr`, áp dụng SG Chaining không mở dải full NodePort. |
| **EC2 Harbor Module** | `terraform/modules/ec2-harbor` | `PARTIAL` (Skeleton) | Mới có Elastic IP. **Thiếu:** `aws_instance` (t3.medium), ổ cứng chuyên dụng EBS 60GB gp3 (`/data`), EIP association, `LabInstanceProfile`. |
| **EC2 K3s Module** | `terraform/modules/ec2-k3s` | `PARTIAL` (Skeleton) | Mới có EIP server và placeholder IP worker. **Thiếu:** `aws_instance` Server (t3.medium), Worker (t3.large), `LabInstanceProfile`. |
| **RDS Module** | `terraform/modules/rds` | `PARTIAL` (Skeleton/Mock) | Mới có khung biến và mock output. **Thiếu:** `aws_db_subnet_group` 2 AZ, parameter group `postgres16`, `aws_db_instance` (PostgreSQL 16, `publicly_accessible = false`). |
| **Ansible Roles** | `ansible/roles/*` | `PARTIAL` (Skeleton) | Cần viết kịch bản thực tế cho `common`, `docker`, `harbor` (TLS SAN + EBS 60GB), `k3s-server` (trust Harbor CA), `k3s-agent`, `monitoring-agent`. |

---

## 3. Kết Luận Baseline Gate 0 (P2-00)

* [x] **IaC Repo:** Nhánh `main` đã chốt tại commit `92f397a` (đã merge PR #1).
* [x] **Backend Repo:** Nhánh `main` tại SHA `91df667` (PR hardening #3 đã merge tại `901fe18`, 63/63 tests PASS, coverage 100%). Release tag `v1.0.0-phase1` trạng thái `PENDING`.
* [x] **Phân định phạm vi:** Xác định chính xác toàn bộ khoảng trống kỹ thuật của Terraform và Ansible cần triển khai trong P2-02 đến P2-08.
* [x] **Nguyên tắc an toàn:** Không tự nhận tài nguyên AWS đã hoàn thành khi mới có file cấu hình; không commit bí mật hay state lên Git.
