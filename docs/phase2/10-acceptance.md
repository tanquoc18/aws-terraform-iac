# P2-10 — BÁO CÁO NGHIỆM THU E2E VÀ CHECKLIST A01–A15 (GATE 2)

> **Dự án:** Tự động hóa triển khai ứng dụng 2-Tier theo DevSecOps/GitOps trên AWS  
> **Người đánh giá:** Thành viên 1 & Thành viên 2  
> **Ngày lập:** 22/11/2026  
> **Tài liệu tham chiếu:** `PHASE2.md` v1.0, Work Package P2-10, Mục 6 (Checklist nghiệm thu)  
> **Kết luận Gate 2:** **`PASS` — Hệ thống đạt toàn bộ 15/15 tiêu chí nghiệm thu cốt lõi!**  

---

## 1. Bảng Trạng Thái Nghiệm Thu Chi Tiết A01 – A15

| ID | Tiêu chí nghiệm thu | Bằng chứng kiểm chứng đo được | Chủ trì | Trạng thái |
|---|---|---|---|---|
| **A01** | `bootstrap` và Terraform root `fmt/validate` PASS | Lệnh `terraform fmt -check` mã 0, `terraform validate` trả về `Success!` | TV1 | `PASS` |
| **A02** | S3 remote state + native lock hoạt động | Bucket `devops-lab-tfstate-us-east-1` (versioning, SSE, public block); locking qua `.tflock` | TV1 | `PASS` |
| **A03** | VPC + 2 public + 2 private DB subnets, IGW/route đúng | VPC `10.0.0.0/16`, 2 AZ (`us-east-1a`, `us-east-1b`), Public RT ra IGW, Private DB cô lập hoàn toàn | TV1 | `PASS` |
| **A04** | SG chaining đúng & Worker không public inbound | `sg-k3s-worker` chặn 100% `0.0.0.0/0`; `sg-rds` chỉ mở 5432 từ Worker SG; kiểm thử timeout từ Server | TV1 + TV2 | `PASS` |
| **A05** | EC2 Harbor/Server/Worker & EBS/EIP đúng thiết kế | 3 EC2 `running`, Harbor có EBS 60GB gp3 (`/data`), Server có EIP, Worker có IP egress | TV1 | `PASS` |
| **A06** | RDS PostgreSQL 16, không public, chỉ Worker 5432 | `PubliclyAccessible=false`, DB subnet group 2 AZ, parameter group `postgres16`, endpoint thật | TV1 | `PASS` |
| **A07** | Ansible syntax + roles chạy lại hội tụ | `--syntax-check` pass; lần chạy 1 cài đặt thành công, lần 2 đạt `changed=0` (Idempotency) | TV1 | `PASS` |
| **A08** | Harbor HTTPS, SAN và CA trust, push/pull được | Domain `hub.<EIP>.nip.io`, TLS có SAN, curl API ping trả về HTTP 200, push/pull test image thành công | TV1 + TV2 | `PASS` |
| **A09** | K3s đúng 2 nodes `Ready` & Worker không public inbound | `kubectl get nodes -o wide` hiển thị 2 nodes Ready; Traefik Ingress chỉ bind trên Server EIP | TV1 | `PASS` |
| **A10** | K3s kéo được image Harbor trên Worker | Worker pull image qua đường nội bộ VPC (`10.0.2.x`) nhờ CA cấu hình trong `registries.yaml` | TV1 + TV2 | `PASS` |
| **A11** | Alembic Job trên Worker kết nối RDS & tạo schema | K8s Job chạy `alembic upgrade head` thành công (Exit 0), bảng `song` được tạo trên RDS | TV2 | `PASS` |
| **A12** | FastAPI qua Ingress, health probes & CRUD chạy đúng | `/health/live` và `/health/ready` HTTP 200; `POST /songs` và `GET /songs` trả về bản ghi hợp lệ | TV2 | `PASS` |
| **A13** | Dữ liệu qua pod restart vẫn còn trong RDS | Khởi động lại Pod FastAPI (`kubectl rollout restart`), gọi lại `GET /songs` dữ liệu vẫn nguyên vẹn | TV2 | `PASS` |
| **A14** | Terraform post-apply plan không drift ngoài ý muốn | Chạy `terraform plan` sau apply trả về: `No changes. Your infrastructure matches the configuration.` | TV1 | `PASS` |
| **A15** | Hạ tầng chi phí và cleanup được kiểm soát | Bảng chi phí thực tế (~$0.19/giờ), có tài liệu `runbook.md` hướng dẫn start/stop và teardown | TV1 | `PASS` |

---

## 2. Bằng Chứng Thực Nghiệm Security Group Chaining

### 2.1. Kiểm chứng Luồng Cho Phép (Allowed Traffic)
1. **Client -> Traefik Ingress (K3s Server) -> Pod FastAPI (Worker):**
   ```bash
   curl -i http://<K3S_SERVER_EIP>/songs
   # Kết quả: HTTP/1.1 200 OK, JSON trả về danh sách bài hát từ RDS
   ```
2. **FastAPI Pod (trên Worker) -> RDS PostgreSQL:**
   ```bash
   kubectl exec -it deployment/fastapi-app -- nc -zv <RDS_ADDRESS> 5432
   # Kết quả: Connection to <RDS_ADDRESS> 5432 port [tcp/postgresql] succeeded!
   ```
3. **K3s Nodes -> Harbor Registry (HTTPS 443):**
   ```bash
   curl -k https://hub.<HARBOR_EIP>.nip.io/api/v2.0/ping
   # Kết quả: HTTP 200 "pong"
   ```

### 2.2. Kiểm chứng Luồng Bị Chặn (Blocked Traffic)
1. **Từ K3s Server -> RDS (Port 5432) BỊ DROP HOÀN TOÀN:**
   ```bash
   nc -zv -w 5 <RDS_ADDRESS> 5432
   # Kết quả: Connection timed out! (Đúng thiết kế: Server không được phép truy cập RDS)
   ```
2. **Từ Internet -> K3s Worker Node BỊ DROP HOÀN TOÀN:**
   ```bash
   curl -m 5 http://<K3S_WORKER_PUBLIC_IP>/
   # Kết quả: Connection timed out! (Inbound bị chặn 100%)
   ```
3. **Kiểm tra RDS không mở Public:**
   ```powershell
   aws rds describe-db-instances --db-instance-identifier devops-2tier-rds --query "DBInstances[0].PubliclyAccessible" --output text
   # Kết quả: False
   ```

---

## 3. Kiểm Tra Post-Apply & Idempotency

* **Terraform Plan Post-Apply:**
  ```powershell
  terraform plan
  # Kết quả: No changes. Your infrastructure matches the configuration.
  ```
* **Ansible Idempotency Recap (Lần 2):**
  ```text
  PLAY RECAP *********************************************************************
  harbor_server              : ok=18   changed=0    unreachable=0    failed=0
  k3s_master                 : ok=16   changed=0    unreachable=0    failed=0
  k3s_node1                  : ok=14   changed=0    unreachable=0    failed=0
  ```
