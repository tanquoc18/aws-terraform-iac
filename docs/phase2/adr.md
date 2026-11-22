# ARCHITECTURAL DECISION RECORDS (ADR) — PHASE 2

> **Dự án:** Tự động hóa triển khai ứng dụng 2-Tier theo DevSecOps/GitOps trên AWS  
> **Bộ quyết định:** ADR-01 đến ADR-12 theo chuẩn `PHASE2.md` v1.0  
> **Người lập:** Thành viên 1 & Thành viên 2  
> **Ngày cập nhật:** 22/11/2026 (Sau khi hoàn tất kiểm tra Preflight AWS Academy)  
> **Trạng thái chung:** **12/12 ADR ĐÃ ĐƯỢC PHÊ DUYỆT (APPROVED)**  

---

### [ADR-01] Vùng Triển Khai (Region) và Availability Zones (AZs)
* **Trạng thái:** `APPROVED`
* **Ngữ cảnh:** Kế hoạch tổng thể gợi ý `ap-southeast-1`, nhưng tài khoản AWS Academy Learner Lab được cấp quyền chính thức tại `us-east-1` (N. Virginia).
* **Quyết định:** 
  - Triển khai toàn bộ hạ tầng tại **`us-east-1`**.
  - Sử dụng 2 Availability Zones có đầy đủ offerings EC2 (`t3.medium`, `t3.large`) và RDS: **`us-east-1a`** (Public Subnet 1, Private DB Subnet 1) và **`us-east-1b`** (Public Subnet 2, Private DB Subnet 2).
* **Hệ quả:** Tham số hóa biến `aws_region = "us-east-1"` trong Terraform, loại bỏ mọi hardcode.

---

### [ADR-02] Môi Trường Tài Khoản AWS và Giới Hạn Lab
* **Trạng thái:** `APPROVED`
* **Ngữ cảnh:** Môi trường AWS Academy giới hạn quyền tạo IAM Role mới (`iam:CreateRole`), cấm NAT Gateway, và phiên làm việc tự động ngắt sau 4 giờ.
* **Quyết định:** 
  - Tận dụng Instance Profile có sẵn của Lab: **`LabInstanceProfile`** (đã gắn sẵn `LabRole`).
  - Không tạo tài nguyên `aws_iam_role` hoặc `aws_iam_instance_profile` trong Terraform để tránh lỗi `AccessDenied`.
  - Không dùng NAT Gateway, cấp Public IP cho Worker node để egress tải image/packages và dùng Security Group chặn toàn bộ inbound từ Internet.

---

### [ADR-03] Định Cỡ Tài Nguyên (Instance Types & Storage)
* **Trạng thái:** `APPROVED`
* **Ngữ cảnh:** Cần cân bằng giữa hiệu năng của cụm Kubernetes (K3s) + Harbor với hạn mức tài chính của Lab.
* **Quyết định:**
  - **EC2 Harbor:** `t3.medium` (2 vCPU, 4GB RAM) + 60GB EBS gp3 riêng biệt cho `/data` registry.
  - **EC2 K3s Server:** `t3.medium` (2 vCPU, 4GB RAM) + 20GB gp3 root volume.
  - **EC2 K3s Worker:** `t3.large` (2 vCPU, 8GB RAM) + 30GB gp3 root volume (đủ RAM chạy FastAPI, Pods, Alembic Job).
  - **RDS PostgreSQL 16:** `db.t3.micro`, 20GB gp3 Storage, Single-AZ (tiết kiệm chi phí).

---

### [ADR-04] Quản Lý Elastic IP và Chi Phí Public IPv4
* **Trạng thái:** `APPROVED`
* **Ngữ cảnh:** AWS tính phí $0.005/giờ cho mỗi Public IPv4/EIP.
* **Quyết định:**
  - Cấp phát đúng **2 Elastic IPs**: 1 EIP cho Harbor (để trỏ tên miền nip.io ổn định) và 1 EIP cho K3s Server (Control Plane & Traefik Ingress).
  - K3s Worker sử dụng Public IP động gắn kèm subnet chỉ dùng cho egress, không cấp EIP riêng.
  - Giải phóng toàn bộ EIP khi teardown lab để tránh trừ tiền ngoài ý muốn.

---

### [ADR-05] Terraform Remote State và Cơ Chế Khóa State (State Locking)
* **Trạng thái:** `APPROVED`
* **Ngữ cảnh:** Terraform 1.11+ giới thiệu tính năng Native S3 State Locking (`use_lockfile = true`) thay thế bảng DynamoDB.
* **Quyết định:**
  - Sử dụng module `bootstrap/` tạo S3 Bucket riêng biệt: bật Versioning, mã hóa SSE-S3 (`AES256`), kích hoạt `block_public_access`.
  - Backend của `terraform/` kích hoạt `use_lockfile = true`, không cần tạo DynamoDB table, tiết kiệm tài nguyên và đơn giản hóa kiến trúc.

---

### [ADR-06] Ghim Phiên Bản Công Cụ (Tooling & Provider Pinning)
* **Trạng thái:** `APPROVED`
* **Ngữ cảnh:** Tránh rủi ro trôi phiên bản (drift) giữa các máy của thành viên.
* **Quyết định:**
  - Terraform Core: `>= 1.11.0` (Đang kiểm thử tại v1.17.0).
  - AWS Provider: Ghim `hashicorp/aws >= 5.30.0` (Đã sinh file lock chuẩn `v6.73.0`).
  - Ansible: Pin `ansible-core >= 2.15`, cài đặt collection `ansible.posix`.

---

### [ADR-07] Phương Thức Quản Trị và Kết Nối Vào Node (Bastion vs SSM)
* **Trạng thái:** `APPROVED`
* **Ngữ cảnh:** Worker node nằm trong thế mạng chặn toàn bộ inbound từ Internet, cần đường vào để chạy Ansible và debug.
* **Quyết định:** 
  - Gắn `iam_instance_profile = "LabInstanceProfile"` cho cả 3 máy chủ EC2 để kích hoạt AWS Systems Manager (SSM Session Manager).
  - Đối với Ansible: Sử dụng K3s Server làm SSH Jump Host (Bastion) bằng SSH ProxyJump nội bộ, hoặc chạy kết nối qua SSH Key chuẩn `devops-lab-key.pem` với rule Worker SG chỉ chấp nhận port 22 từ Server SG.

---

### [ADR-08] Harbor TLS Certificate và Chiến Lược Domain Tên Miền
* **Trạng thái:** `APPROVED`
* **Ngữ cảnh:** Cần cung cấp container registry bảo mật qua giao thức HTTPS.
* **Quyết định:**
  - Sử dụng dịch vụ DNS wildcard miễn phí: `hub.<HARBOR_EIP>.nip.io`.
  - Sinh chứng chỉ Self-Signed CA nội bộ với SAN khớp với domain nip.io.
  - Phân phối Root CA của Harbor vào `/etc/rancher/k3s/registries.yaml` và hệ thống của các K3s nodes để tin cậy cert khi kéo image, không dùng cờ `--insecure-registry`.

---

### [ADR-09] Phiên Bản K3s và Cơ Chế Lưu Trữ Datastore
* **Trạng thái:** `APPROVED`
* **Ngữ cảnh:** Triển khai cụm Kubernetes gọn nhẹ cho lab.
* **Quyết định:**
  - Phiên bản: K3s `v1.29.5+k3s1` (hoặc bản ổn định tương đương).
  - Datastore: Sử dụng embedded SQLite mặc định trên Server node (đáp ứng tiêu chuẩn single control-plane lab).
  - Ingress: Giữ nguyên Traefik Ingress Controller mặc định của K3s trên Server node.

---

### [ADR-10] Quản Lý Bí Mật và Thông Số RDS (Secrets Management)
* **Trạng thái:** `APPROVED`
* **Ngữ cảnh:** Tránh rò rỉ master password của database lên Git hoặc log.
* **Quyết định:**
  - Biến `db_password` được đánh dấu `sensitive = true` trong Terraform.
  - Giá trị mật khẩu chỉ truyền qua biến môi trường `TF_VAR_db_password` hoặc file `terraform.tfvars` (đã nằm trong `.gitignore`).
  - Phía Kubernetes: mật khẩu được nạp vào Kubernetes Secret khi deploy pod, không commit manifest chứa secret plaintext.

---

### [ADR-11] Chiến Lược Chạy Database Migration và Triển Khai Ứng Dụng
* **Trạng thái:** `APPROVED`
* **Ngữ cảnh:** Tránh lỗi HTTP 500 do API khởi động trước khi database được khởi tạo bảng `song`.
* **Quyết định:**
  - Khởi tạo K8s Migration Job chạy lệnh `alembic upgrade head` trên K3s Worker trước.
  - Chỉ khi Job hoàn thành thành công (Exit 0), Deployment của FastAPI mới bắt đầu mở Pod phục vụ traffic.
  - Security Group của RDS chỉ chấp nhận kết nối TCP port 5432 từ Security Group của Worker.

---

### [ADR-12] Quy Trình Teardown và Bảo Tồn Dữ Liệu Sau Phiên Lab
* **Trạng thái:** `APPROVED`
* **Ngữ cảnh:** Tránh vượt hạn mức chi phí của tài khoản Lab sau khi kết thúc buổi thực hành.
* **Quyết định:**
  - Hết mỗi phiên làm việc: Thực hiện dừng (Stop) các EC2 instances để dừng tính phí vCPU/RAM.
  - Khi nghiệm thu hoàn tất Phase 2: Chụp snapshot RDS (nếu cần giữ dữ liệu), sau đó xin ý kiến nhóm và chạy `terraform destroy` theo runbook được kiểm duyệt.
  - Không xóa bucket chứa remote state bootstrap khi chưa có sự đồng thuận của cả 2 thành viên.
