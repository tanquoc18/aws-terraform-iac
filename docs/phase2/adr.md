# ARCHITECTURAL DECISION RECORDS (ADR) — PHASE 2

> **Dự án:** Tự động hóa triển khai ứng dụng 2-Tier theo DevSecOps/GitOps trên AWS  
> **Bộ quyết định:** ADR-01 đến ADR-12 theo chuẩn `PHASE2.md` v1.0  
> **Người lập:** Thành viên 1 & Thành viên 2  
> **Ngày cập nhật:** 23/11/2026  
> **Quy tắc:** Chỉ đánh dấu `APPROVED` khi CẢ HAI THÀNH VIÊN đã đối chiếu và ký nhận. Các mục còn lại ở trạng thái `PENDING_REVIEW` hoặc `PROPOSED`.  

---

### [ADR-01] Vùng Triển Khai (Region) và Availability Zones (AZs)
* **Trạng thái:** `PENDING_REVIEW` (Thành viên 1 đề xuất dựa trên kết quả Preflight)
* **Ngữ cảnh:** Kế hoạch tổng thể gợi ý `ap-southeast-1`, nhưng tài khoản AWS Academy Learner Lab được cấp quyền chính thức tại `us-east-1` (N. Virginia).
* **Đề xuất:** 
  - Triển khai toàn bộ hạ tầng tại **`us-east-1`**.
  - Sử dụng 2 Availability Zones có đầy đủ offerings EC2 (`t3.medium`, `t3.large`) và RDS: **`us-east-1a`** (Public Subnet 1, Private DB Subnet 1) và **`us-east-1b`** (Public Subnet 2, Private DB Subnet 2).
* **Hệ quả:** Tham số hóa biến `aws_region = "us-east-1"` và `availability_zones = ["us-east-1a", "us-east-1b"]` trong Terraform, loại bỏ mọi hardcode.

---

### [ADR-02] Môi Trường Tài Khoản AWS và Giới Hạn Lab
* **Trạng thái:** `PENDING_REVIEW`
* **Ngữ cảnh:** Môi trường AWS Academy giới hạn quyền tạo IAM Role mới (`iam:CreateRole`), cấm NAT Gateway, và phiên làm việc tự động ngắt sau 4 giờ.
* **Đề xuất:** 
  - Tận dụng Instance Profile có sẵn của Lab: **`LabInstanceProfile`** (đã gắn sẵn `LabRole`).
  - Không tạo tài nguyên `aws_iam_role` hoặc `aws_iam_instance_profile` trong Terraform để tránh lỗi `AccessDenied`.
  - Không dùng NAT Gateway; cấp Public IP cho Worker node để egress tải image/packages và dùng Security Group chặn 100% inbound từ Internet.

---

### [ADR-03] Định Cỡ Tài Nguyên (Instance Types & Storage)
* **Trạng thái:** `PENDING_REVIEW`
* **Ngữ cảnh:** Cần cân bằng giữa hiệu năng của cụm Kubernetes (K3s) + Harbor với hạn mức tài chính của Lab.
* **Đề xuất:**
  - **EC2 Harbor:** `t3.medium` (2 vCPU, 4GB RAM) + 20GB gp3 root + 60GB EBS gp3 riêng biệt cho `/data` registry.
  - **EC2 K3s Server:** `t3.medium` (2 vCPU, 4GB RAM) + 20GB gp3 root volume.
  - **EC2 K3s Worker:** `t3.large` (2 vCPU, 8GB RAM) + 30GB gp3 root volume (đủ RAM chạy FastAPI, Pods, Alembic Job).
  - **RDS PostgreSQL 16:** `db.t3.micro`, 20GB gp3 Storage, Single-AZ (tiết kiệm chi phí).
  - **Tổng dung lượng EBS:** 130 GB gp3.

---

### [ADR-04] Quản Lý Elastic IP và Chi Phí Public IPv4
* **Trạng thái:** `PENDING_REVIEW`
* **Ngữ cảnh:** AWS tính phí $0.005/giờ cho mỗi địa chỉ Public IPv4 (kể cả EIP lẫn Public IP gán tự động).
* **Đề xuất:**
  - Cấp phát đúng **2 Elastic IPs**: 1 EIP cho Harbor (để trỏ tên miền nip.io ổn định) và 1 EIP cho K3s Server (Control Plane & Traefik Ingress).
  - K3s Worker sử dụng Public IP động gắn kèm subnet chỉ dùng cho egress, không cấp EIP riêng.
  - Tổng số Public IPv4 hoạt động đồng thời là **3 IPs**.
  - Giải phóng toàn bộ EIP khi teardown lab để tránh bị phạt phí unassociated.

---

### [ADR-05] Terraform Remote State và Cơ Chế Khóa State (State Locking)
* **Trạng thái:** `PENDING_REVIEW`
* **Ngữ cảnh:** Terraform 1.11+ giới thiệu tính năng Native S3 State Locking (`use_lockfile = true`) thay thế bảng DynamoDB.
* **Đề xuất:**
  - Sử dụng module `bootstrap/` tạo S3 Bucket riêng biệt (`devops-lab-tfstate-us-east-1`): bật Versioning, mã hóa SSE-S3 (`AES256`), kích hoạt `block_public_access`.
  - Backend của `terraform/` kích hoạt `use_lockfile = true`, không cần tạo DynamoDB table, tiết kiệm tài nguyên và đơn giản hóa kiến trúc.

---

### [ADR-06] Ghim Phiên Bản Công Cụ & Quản Lý Provider Lock (Tooling & Lockfile Pinning)
* **Trạng thái:** `PENDING_REVIEW`
* **Ngữ cảnh:** Tránh rủi ro trôi phiên bản (drift) giữa các máy của thành viên; phân biệt giữa version constraint và version lock thực tế.
* **Đề xuất:**
  - **Terraform Core:** `>= 1.11.0` (Được hỗ trợ đầy đủ tính năng `use_lockfile`).
  - **AWS Provider Constraint:** Khai báo `source = "hashicorp/aws", version = ">= 5.30.0"` trong `versions.tf`.
  - **Provider Lockfile:** File `.terraform.lock.hcl` ghim chính xác phiên bản triển khai cụ thể (ví dụ `v6.73.0`) và **phải được theo dõi trong Git** (loại bỏ khỏi `.gitignore` nếu có) để bảo đảm mọi thành viên chạy cùng binary provider đã kiểm định.
  - **Ansible:** Pin `ansible-core >= 2.15`, cài đặt collections `ansible.posix` và `community.general`.

---

### [ADR-07] Phương Thức Quản Trị và Đường Kết Nối Node (Chốt Phương Án Worker)
* **Trạng thái:** `PROPOSED` (Đã chốt phương án kỹ thuật cho Worker, chờ TV2 review)
* **Ngữ cảnh:** K3s Worker node nằm ở mạng chặn 100% inbound từ Internet (`0.0.0.0/0`), cần đường kết nối an toàn để Ansible cấu hình và quản trị viên debug.
* **Quyết định đề xuất:** 
  - **Đường quản trị chính (Ansible & SSH):** Sử dụng **SSH ProxyJump qua K3s Server Bastion**. K3s Server mở port 22 SSH cho `my_ip_cidr`; K3s Worker chỉ mở port 22 SSH nội bộ nhận từ Security Group của Server. Cấu hình Ansible dùng `ProxyJump=ubuntu@<SERVER_EIP>` và bật xác thực host key tin cậy (`StrictHostKeyChecking=accept-new`), không tắt host key checking.
  - **Đường quản trị dự phòng (Out-of-Band):** Gắn `iam_instance_profile = "LabInstanceProfile"` cho cả 3 máy chủ EC2 để kích hoạt AWS Systems Manager (SSM Session Manager) khi cần can thiệp mà không phụ thuộc vào SSH.
  - **Cam kết:** Tuyệt đối không mở port 22 của Worker ra Internet công cộng.

---

### [ADR-08] Harbor TLS Certificate và Chiến Lược Domain Tên Miền
* **Trạng thái:** `PENDING_REVIEW`
* **Ngữ cảnh:** Cần cung cấp container registry bảo mật qua giao thức HTTPS; tránh cờ không an toàn `--insecure-registry`.
* **Đề xuất:**
  - Sử dụng dịch vụ DNS wildcard miễn phí: `hub.<HARBOR_EIP>.nip.io`.
  - Sinh chứng chỉ Self-Signed CA nội bộ với SAN khớp với domain nip.io và IP nội bộ.
  - Phân phối Root CA của Harbor vào `/etc/rancher/k3s/registries.yaml` và hệ thống của các K3s nodes để tin cậy cert khi kéo image, bắt buộc xác thực TLS hợp lệ.

---

### [ADR-09] Phiên Bản K3s và Cơ Chế Lưu Trữ Datastore
* **Trạng thái:** `PENDING_REVIEW` (Cập nhật phiên bản còn hỗ trợ)
* **Ngữ cảnh:** Triển khai cụm Kubernetes gọn nhẹ cho lab; phiên bản v1.29.5 đã cũ.
* **Đề xuất:**
  - **Phiên bản K3s:** Sử dụng phiên bản ổn định được hỗ trợ tích cực theo SUSE Product Support Lifecycle: **`v1.35.10+k3s1`** (nhánh K3s v1.35 được duy trì hỗ trợ đến 2027, thay thế phiên bản v1.30 đã kết thúc hỗ trợ vào tháng 06/2025).
  - **Datastore:** Sử dụng embedded SQLite mặc định trên Server node (đáp ứng tiêu chuẩn single control-plane lab).
  - **Ingress Controller & ServiceLB:** Sử dụng Traefik Ingress Controller mặc định. Cấu hình ServiceLB chọn node bằng allow-list: Server node được gán `--node-label svccontroller.k3s.cattle.io/enablelb=true`, Worker node **hoàn toàn không gán nhãn `enablelb`** để ServiceLB controller chỉ chọn Server node làm public entrypoint cho cổng 80/443.

---

### [ADR-10] Quản Lý Bí Mật và Thông Số RDS (Secrets Management)
* **Trạng thái:** `PENDING_REVIEW`
* **Ngữ cảnh:** Tránh rò rỉ master password của database lên Git hoặc log.
* **Đề xuất:**
  - Biến `db_password` được đánh dấu `sensitive = true` trong Terraform.
  - Giá trị mật khẩu chỉ truyền qua biến môi trường `TF_VAR_db_password` hoặc file `terraform.tfvars` (đã nằm trong `.gitignore`).
  - Phía Kubernetes: mật khẩu được nạp vào Kubernetes Secret khi deploy pod, không commit manifest chứa secret plaintext.

---

### [ADR-11] Chiến Lược Chạy Database Migration và Triển Khai Ứng Dụng
* **Trạng thái:** `PENDING_REVIEW`
* **Ngữ cảnh:** Tránh lỗi HTTP 500 do API khởi động trước khi database được khởi tạo bảng `song`.
* **Đề xuất:**
  - Khởi tạo K8s Migration Job chạy lệnh `alembic upgrade head` trên K3s Worker trước (khớp với SG của RDS).
  - Chỉ khi Job hoàn thành thành công (Exit 0), Deployment của FastAPI mới bắt đầu mở Pod phục vụ traffic.
  - Security Group của RDS chỉ chấp nhận kết nối TCP port 5432 từ Security Group của Worker.

---

### [ADR-12] Quy Trình Teardown và Bảo Tồn Dữ Liệu Sau Phiên Lab
* **Trạng thái:** `PENDING_REVIEW`
* **Ngữ cảnh:** Tránh vượt hạn mức chi phí của tài khoản Lab sau khi kết thúc buổi thực hành.
* **Đề xuất:**
  - Hết mỗi phiên làm việc: Thực hiện dừng (Stop) các EC2 instances để dừng tính phí vCPU/RAM.
  - Khi nghiệm thu hoàn tất Phase 2: Chụp snapshot RDS (nếu cần giữ dữ liệu), sau đó xin ý kiến nhóm và chạy `terraform destroy` theo runbook được kiểm duyệt.
  - Không xóa bucket chứa remote state bootstrap khi chưa có sự đồng thuận của cả 2 thành viên.
