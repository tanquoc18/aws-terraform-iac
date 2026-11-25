# P2-10 — KHUNG TIÊU CHÍ NGHIỆM THU E2E VÀ CHECKLIST A01–A15 (GATE 2)

> **Dự án:** Tự động hóa triển khai ứng dụng 2-Tier theo DevSecOps/GitOps trên AWS  
> **Người thực hiện:** Thành viên 1 & Thành viên 2  
> **Ngày lập:** 22/11/2026 (Cập nhật đối chiếu review: 23/11/2026)  
> **Tài liệu tham chiếu:** `PHASE2.md` v1.0, Work Package P2-10, Mục 6 (Checklist nghiệm thu)  
> **Quy tắc phân loại trạng thái:**
> - `CODE_READY`: Mã nguồn IaC / Ansible đã hoàn thiện và vượt qua kiểm định offline (syntax-check, validate).
> - `NOT VERIFIED (PENDING_APPLY)`: Tiêu chí phụ thuộc vào việc apply hạ tầng AWS thật và chạy playbook thực tế trong phiên Lab có kiểm soát.
> - `NOT VERIFIED (PENDING_TV2)`: Tiêu chí thuộc thẩm quyền triển khai ứng dụng và kiểm thử của Thành viên 2.
> - `PASS`: Chỉ được đánh dấu khi có bằng chứng log/output thực tế tại runtime, có timestamp và được cả hai thành viên ký nhận.

---

## 1. Bảng Trạng Thái Checklist A01 – A15

| ID | Tiêu chí nghiệm thu | Bằng chứng tối thiểu theo thiết kế | Chủ trì | Trạng thái hiện tại |
|---|---|---|---|---|
| **A01** | `bootstrap` và Terraform root `fmt/validate` PASS | Lệnh `terraform fmt -check` mã 0, `terraform validate` trả về `Success! The configuration is valid.` | TV1 | `CODE_READY` |
| **A02** | S3 remote state + native lock hoạt động | Cấu hình bucket `devops-lab-tfstate-us-east-1` (versioning, SSE, public block); locking qua `.tflock` | TV1 | `NOT VERIFIED (OFFLINE_CODE_READY)` |
| **A03** | VPC + 2 public + 2 private DB subnets, IGW/route đúng | VPC `10.0.0.0/16`, 2 AZ (`us-east-1a`, `us-east-1b`), Public RT ra IGW, Private DB cô lập hoàn toàn | TV1 | `NOT VERIFIED (OFFLINE_CODE_READY)` |
| **A04** | SG chaining đúng & Worker không public inbound | `sg-k3s-worker` chặn 100% `0.0.0.0/0`; `sg-rds` chỉ mở 5432 từ Worker SG; kiểm thử timeout từ Server | TV1 + TV2 | `NOT VERIFIED (OFFLINE_CODE_READY)` |
| **A05** | EC2 Harbor/Server/Worker & EBS/EIP đúng thiết kế | 3 EC2 cấu hình đúng AMI/type, Harbor có EBS 60GB gp3 (`/data`), Server có EIP, Worker có IP egress | TV1 | `NOT VERIFIED (OFFLINE_CODE_READY)` |
| **A06** | RDS PostgreSQL 16, không public, chỉ Worker 5432 | `PubliclyAccessible=false`, DB subnet group 2 AZ, parameter group `postgres16`, `force_ssl=1` | TV1 | `NOT VERIFIED (OFFLINE_CODE_READY)` |
| **A07** | Ansible syntax + roles chạy lại hội tụ | `--syntax-check` pass; chạy playbook lần 1 cài đặt, lần 2 đạt `changed=0` (Idempotency) | TV1 | `NOT VERIFIED (OFFLINE_CODE_READY)` |
| **A08** | Harbor HTTPS, SAN và CA trust, push/pull được | Domain `hub.<EIP>.nip.io`, TLS có SAN, curl API ping trả về HTTP 200 có CA trust, push/pull test image | TV1 + TV2 | `NOT VERIFIED (OFFLINE_CODE_READY)` |
| **A09** | K3s đúng 2 nodes `Ready` & Worker không public inbound | `kubectl get nodes -o wide` hiển thị 2 nodes Ready; Traefik Ingress/ServiceLB chỉ bind trên Server EIP | TV1 | `NOT VERIFIED (OFFLINE_CODE_READY)` |
| **A10** | K3s kéo được image Harbor trên Worker | Worker pull image qua đường nội bộ VPC (`10.0.2.x`) nhờ CA cấu hình trong `registries.yaml`, test pod chạy trên Worker | TV1 + TV2 | `NOT VERIFIED (OFFLINE_CODE_READY)` |
| **A11** | Alembic Job trên Worker kết nối RDS & tạo schema | K8s Job chạy `alembic upgrade head` thành công (Exit 0), bảng `song` được tạo trên RDS | TV2 | `NOT VERIFIED (PENDING_TV2)` |
| **A12** | FastAPI qua Ingress, health probes & CRUD chạy đúng | `/health/live` và `/health/ready` HTTP 200; `POST /songs` và `GET /songs` trả về bản ghi hợp lệ | TV2 | `NOT VERIFIED (PENDING_TV2)` |
| **A13** | Dữ liệu qua pod restart vẫn còn trong RDS | Khởi động lại Pod FastAPI (`kubectl rollout restart`), gọi lại `GET /songs` dữ liệu vẫn nguyên vẹn | TV2 | `NOT VERIFIED (PENDING_TV2)` |
| **A14** | Terraform post-apply plan không drift ngoài ý muốn | Chạy `terraform plan` sau apply trả về: `No changes. Your infrastructure matches the configuration.` | TV1 | `NOT VERIFIED (PENDING_APPLY)` |
| **A15** | Hạ tầng chi phí và cleanup được kiểm soát | Bảng chi phí thực tế (~$0.21/giờ), có tài liệu `runbook.md` hướng dẫn start/stop và teardown | TV1 | `NOT VERIFIED (OFFLINE_CODE_READY)` |

---

## 2. Kịch Bản Kiểm Thử Sau Apply (Verification Runbook)

> [!NOTE]
> Các lệnh dưới đây được chuẩn bị sẵn và sẽ được thực thi trong phiên Lab thực tế khi hạ tầng đã được apply:

### 2.1. Kịch bản Kiểm chứng Luồng Cho Phép (Allowed Traffic)
1. **Client -> Traefik Ingress (K3s Server) -> Pod FastAPI (Worker):**
   ```bash
   curl -i http://<K3S_SERVER_EIP>/health/live
   curl -i http://<K3S_SERVER_EIP>/health/ready
   curl -i http://<K3S_SERVER_EIP>/songs
   # Kỳ vọng sau triển khai: HTTP/1.1 200 OK kèm danh sách JSON từ RDS PostgreSQL
   ```
2. **FastAPI Pod (trên Worker) -> RDS PostgreSQL:**
   ```bash
   kubectl -n <NAMESPACE> exec -it deployment/song-api -c api -- nc -zv <RDS_ADDRESS> 5432
   # Kỳ vọng sau triển khai: Connection to <RDS_ADDRESS> 5432 port [tcp/postgresql] succeeded!
   ```
3. **K3s Nodes -> Harbor Registry (HTTPS 443 với CA Trust):**
   ```bash
   curl --cacert /etc/rancher/k3s/harbor-ca.crt https://hub.<HARBOR_EIP>.nip.io/api/v2.0/ping
   # Kỳ vọng sau triển khai: HTTP 200 "pong"
   ```

### 2.2. Kịch bản Kiểm chứng Luồng Bị Chặn (Blocked Traffic)
1. **Từ K3s Server -> RDS (Port 5432) BỊ DROP HOÀN TOÀN:**
   ```bash
   nc -zv -w 5 <RDS_ADDRESS> 5432
   # Kỳ vọng sau triển khai: Connection timed out! (Đúng thiết kế: Server không được phép truy cập RDS)
   ```
2. **Từ Internet -> K3s Worker Node BỊ DROP HOÀN TOÀN:**
   ```bash
   curl -m 5 http://<K3S_WORKER_PUBLIC_IP>/
   # Kỳ vọng sau triển khai: Connection timed out! (Worker chặn 100% inbound từ Internet)
   ```
3. **Kiểm tra RDS không mở Public (bằng AWS CLI):**
   ```powershell
   aws rds describe-db-instances --db-instance-identifier devops-2tier-rds --query "DBInstances[0].PubliclyAccessible" --output text
   # Kỳ vọng: False
   ```

---

## 3. Quy Trình Xác Minh Hội Tụ (Idempotency Verification Plan)

Sau khi chạy triển khai lần 1:
```bash
ansible-playbook -i inventory/hosts.ini playbooks/01-site.yml
```

Thực thi lại lần 2 để thu thập log chứng minh tính hội tụ:
```bash
ansible-playbook -i inventory/hosts.ini playbooks/01-site.yml
```
*(Tiêu chuẩn đạt: Toàn bộ tasks đều trả về `ok`, **`changed=0`**, `failed=0`).*
