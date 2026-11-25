# P2-05 — BIÊN BẢN REVIEW TERRAFORM PLAN VÀ KIỂM CHỨNG APPLY (GATE 1)

> **Dự án:** Tự động hóa triển khai ứng dụng 2-Tier theo DevSecOps/GitOps trên AWS  
> **Người thực hiện:** Thành viên 1 (Cloud Infrastructure & Platform Engineer)  
> **Người review & chấp thuận:** Thành viên 2 (Application & DevSecOps Engineer)  
> **Ngày lập:** 22/11/2026  
> **Tài liệu tham chiếu:** `PHASE2.md` v1.0, Work Package P2-05 (Gate 1)  
> **Trạng thái:** `PENDING_REVIEW` (Chờ 2 thành viên review bản Plan trước khi Apply)  

---

## 1. Kết Quả Khởi Tạo S3 Remote State (`bootstrap/`)

| Hạng mục S3 State Bucket | Cấu hình thực tế | Trạng thái AWS Runtime |
|---|---|---|
| **Tên Bucket S3** | `devops-lab-tfstate-us-east-1` | `NOT APPLIED` (Chờ chạy bootstrap apply tại Gate 1) |
| **Khu vực (Region)** | `us-east-1` | `TBD — template kiểm chứng` |
| **Versioning** | `Enabled` (bảo vệ lịch sử và rollback state) | `TBD — template kiểm chứng` |
| **Mã hóa (SSE)** | `AES256` (SSE-S3, tối ưu chi phí) | `TBD — template kiểm chứng` |
| **Public Access Block** | Chặn 100% Public Access (4/4 flags = true) | `TBD — template kiểm chứng` |
| **State Locking** | S3 Native Locking (`use_lockfile = true`) | `TBD — template kiểm chứng` |

---

## 2. Bảng Rà Soát Chi Tiết `terraform plan` (Dành cho TV1 và TV2 Review)

> [!IMPORTANT]
> **Cam kết an toàn Gate 1:** Không chạy `terraform apply` cho đến khi toàn bộ các tiêu chí trong bảng dưới đây được cả 2 thành viên đối chiếu và ký nhận `APPROVED`.

| Tiêu chí kỹ thuật | Chi tiết kiểm chứng trong Plan | Kết quả đối chiếu | TV2 Review |
|---|---|---|---|
| **Tổng số tài nguyên tạo mới** | Thêm mới ~25-28 resources, 0 thay đổi, 0 hủy | Chờ đối chiếu `plan` | `[ ]` |
| **VPC & Subnets** | CIDR `10.0.0.0/16`, 2 Public + 2 Private DB subnets | Khớp design P2-03 | `[ ]` |
| **Phân bổ AZ** | Đúng 2 AZ đã chốt: `us-east-1a` và `us-east-1b` | Khớp Gate 0 preflight | `[ ]` |
| **Không dùng NAT Gateway** | Không có tài nguyên `aws_nat_gateway` phát sinh phí | Khớp ngân sách | `[ ]` |
| **EC2 Harbor** | `t3.medium`, 20GB root gp3, EIP gắn kèm | Đúng cấu hình | `[ ]` |
| **Harbor Dedicated EBS** | **60GB gp3** (`aws_ebs_volume.harbor_data`) gắn `/dev/xvdf` | Đủ dung lượng Docker | `[ ]` |
| **EC2 K3s Server** | `t3.medium`, 20GB root gp3, EIP gắn kèm | Đúng cấu hình | `[ ]` |
| **EC2 K3s Worker** | `t3.large`, 30GB root gp3, Public IP egress | Đủ tài nguyên K8s | `[ ]` |
| **IAM Instance Profile** | Gắn `LabInstanceProfile` có sẵn cho cả 3 EC2 | Tránh lỗi AccessDenied | `[ ]` |
| **RDS PostgreSQL 16** | `db.t3.micro`, 20GB gp3, PG `16.9` | Đúng bản đã check | `[ ]` |
| **RDS Private Isolation** | **`publicly_accessible = false`** | An toàn dữ liệu | `[ ]` |
| **RDS DB Subnet Group** | Bao phủ 2 AZ (`us-east-1a` và `us-east-1b`) | Đúng chuẩn AWS RDS | `[ ]` |
| **Worker Inbound** | **100% chặn `0.0.0.0/0`**, xóa full NodePort | Đúng matrix §2.2 | `[ ]` |
| **RDS Inbound Chaining** | **CHỈ MỞ 5432 TỪ `sg-k3s-worker`** | Đúng chuẩn 2-Tier | `[ ]` |
| **Admin Access (SSH/API)** | Port 22 và Port 6443 chỉ mở cho `my_ip_cidr` | Không expose Internet | `[ ]` |
| **Bảo mật Secrets** | `db_password` và các endpoints là `sensitive` | Không lộ plaintext | `[ ]` |

---

## 3. Nhật Ký Thực Thi `terraform apply` (Template Ghi Nhận Khi Được Phê Duyệt Gate 1)

> [!NOTE]
> **Quy định minh bạch trạng thái:** Mục này là **Template biểu mẫu** dành cho quá trình triển khai thực tế trên AWS. Hiện tại chưa chạy apply trên AWS, toàn bộ các giá trị runtime được đánh dấu `NOT APPLIED` / `TBD` để phân biệt rõ giữa "Cấu hình đã khai báo trong Code" và "Bằng chứng đã kiểm chứng trên Runtime".

- **Trạng thái thực thi:** `NOT APPLIED` (Chưa được phép chạy apply trên AWS)
- **Thời gian Apply:** `TBD — Sau khi có chữ ký phê duyệt Gate 1`
- **Người thực thi:** Thành viên 1
- **Exit Code:** `TBD (Chưa thực thi)`
- **Tóm tắt tài nguyên sau Apply (Biểu mẫu điền sau khi apply thật):**
  + **Harbor Instance ID / EIP:** `TBD (i-xxxxxxx / x.x.x.x)`
  + **Harbor Dedicated EBS Volume ID:** `TBD (vol-xxxxxxx)`
  + **K3s Server Instance ID / EIP:** `TBD (i-xxxxxxx / x.x.x.x)`
  + **K3s Worker Instance ID / Public IP:** `TBD (i-xxxxxxx / x.x.x.x)`
  + **RDS Endpoint (Sanitized):** `TBD (devops-2tier-rds.xxxxxx.us-east-1.rds.amazonaws.com:5432)`

---

## 4. Biên Bản Kiểm Chứng Tài Nguyên Thật Bằng AWS CLI (Read-Only)

```powershell
# 1. Kiểm tra 3 EC2 Instances đang ở trạng thái 'running'
aws ec2 describe-instances --filters "Name=tag:Project,Values=devops-2tier" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].{ID:InstanceId,Type:InstanceType,Role:Tags[?Key=='Role'].Value|[0],PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress,State:State.Name}" --output table

# 2. Kiểm tra EBS 60GB đã gắn vào EC2 Harbor
aws ec2 describe-volumes --filters "Name=tag:Name,Values=*harbor-data-60gb*" --query "Volumes[*].{VolumeId:VolumeId,Size:Size,Type:VolumeType,State:State,InstanceId:Attachments[0].InstanceId}" --output table

# 3. Kiểm tra RDS Instance available và KHÔNG public
aws rds describe-db-instances --db-instance-identifier devops-2tier-rds --query "DBInstances[*].{DBId:DBInstanceIdentifier,Class:DBInstanceClass,Engine:Engine,Version:EngineVersion,Status:DBInstanceStatus,PubliclyAccessible:PubliclyAccessible,Endpoint:Endpoint.Address}" --output table

# 4. Kiểm tra 2 Elastic IPs đã gắn thành công
aws ec2 describe-addresses --filters "Name=tag:Project,Values=devops-2tier" --query "Addresses[*].{PublicIp:PublicIp,AllocationId:AllocationId,InstanceId:InstanceId}" --output table
```

---

## 5. Kết Luận Gate 1

- Trạng thái: **`PENDING_APPROVAL`**
- Chữ ký xác nhận Review Plan của TV2: `[ ] Đã đồng ý cho phép Apply`
