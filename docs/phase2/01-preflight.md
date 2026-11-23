# P2-01 — BÁO CÁO AWS PREFLIGHT, NGÂN SÁCH VÀ QUYỀN HẠN LAB

> **Dự án:** Tự động hóa triển khai ứng dụng 2-Tier theo DevSecOps/GitOps trên AWS  
> **Thực hiện:** Thành viên 1 (Cloud Infrastructure & Platform Engineer)  
> **Ngày thực hiện kiểm tra:** 22/11/2026 lúc 22:17 (Giờ VN)  
> **Tài liệu tham chiếu:** `PHASE2.md` v1.0, Work Package P2-01  
> **Trạng thái Gate 0 Preflight:** `PARTIAL_VERIFIED` (Đã xác minh thông số chỉ đọc; các quyền khởi tạo cần kiểm chứng lúc apply)  

---

## 1. Thông tin Phiên làm việc và Danh tính AWS (Caller Identity)

| Thông số | Giá trị xác minh (Public Report Sanitized) | Trạng thái | Ghi chú |
|---|---|---|---|
| **AWS Account** | AWS Academy Learner Lab (Masked) | `VERIFIED` | Tài khoản thực hành có kiểm soát quota |
| **IAM Caller Role** | `voclabs/LabSession` (Assumed Role) | `VERIFIED` | Quyền tạm thời cấp qua STS session |
| **IAM Instance Profile** | `LabInstanceProfile` | `VERIFIED` | Profile gán cho EC2 Harbor, Server, Worker |
| **Default Region** | `us-east-1` (US East - N. Virginia) | `VERIFIED` | Khu vực mặc định được cấp quyền |

*Log thực tế (Sanitized):*
```json
{
  "CallerIdentity": "VERIFIED_VALID",
  "AuthMechanism": "STS_ASSUMED_ROLE",
  "SessionRole": "voclabs/LabSession",
  "Region": "us-east-1"
}
```

---

## 2. Kết Quả Kiểm Tra Availability Zones (AZ) Khả Dụng

Lệnh thực thi: `ec2.describe_availability_zones(Filters=[{'Name': 'state', 'Values': ['available']}])`  
Tại `us-east-1`, hệ thống trả về đủ **6 Availability Zones** ở trạng thái `available`:

| AZ Name | Zone ID | Trạng thái kiểm tra | Lựa chọn kiến trúc cho VPC Subnets |
|---|---|---|---|
| `us-east-1a` | `use1-az6` | `VERIFIED` (available) | **CHỌN LÀM AZ 1** (Public Subnet 1 + Private DB Subnet 1) |
| `us-east-1b` | `use1-az1` | `VERIFIED` (available) | **CHỌN LÀM AZ 2** (Public Subnet 2 + Private DB Subnet 2) |
| `us-east-1c` | `use1-az2` | `VERIFIED` (available) | Dự phòng |
| `us-east-1d` | `use1-az4` | `VERIFIED` (available) | Dự phòng |
| `us-east-1e` | `use1-az3` | `VERIFIED` (available) | Không hỗ trợ dòng t3 |
| `us-east-1f` | `use1-az5` | `VERIFIED` (available) | Dự phòng |

---

## 3. Kết Quả Kiểm Tra EC2 Instance Offerings (`t3.medium`, `t3.large`)

Lệnh thực thi: `ec2.describe_instance_type_offerings(LocationType='availability-zone', Filters=[{'Name': 'instance-type', 'Values': ['t3.medium', 't3.large']}])`

| Instance Type | vCPU | RAM | Mục đích sử dụng | Khả dụng tại `us-east-1a` | Khả dụng tại `us-east-1b` | Trạng thái |
|---|---|---|---|---|---|---|
| `t3.medium` | 2 | 4 GiB | EC2 Harbor Registry | **CÓ** | **CÓ** | `VERIFIED` |
| `t3.medium` | 2 | 4 GiB | EC2 K3s Control Plane Server | **CÓ** | **CÓ** | `VERIFIED` |
| `t3.large` | 2 | 8 GiB | EC2 K3s Worker Node | **CÓ** | **CÓ** | `VERIFIED` |

---

## 4. Kết Quả Kiểm Tra RDS PostgreSQL 16 Offerings

Lệnh thực thi: `rds.describe_orderable_db_instance_options(Engine='postgres')`  
Tìm thấy **56 tùy chọn cấu hình hợp lệ** cho PostgreSQL 16:
* **Instance Class khả dụng:** Cả `db.t3.micro` (x86_64) và `db.t4g.micro` (Graviton2).
* **Engine Version:** Hỗ trợ bản PostgreSQL `16.9` (và các bản 16.x).
* **Storage Type:** Hỗ trợ chuẩn `gp3` (và gp2, io1, io2).
* **Đề xuất triển khai:** `db.t3.micro`, Engine PostgreSQL 16.x, Storage 20GB gp3, `Single-AZ` (không MultiAZ) để tối ưu chi phí.
* **Trạng thái:** `VERIFIED`

---

## 5. Phân Định Quyền Hạn & Quota: Đã Xác Minh vs Chưa Kiểm Chứng

| Hạng mục kiểm tra | Chi tiết kiểm chứng | Trạng thái | Đánh giá & Rủi ro |
|---|---|---|---|
| **EIP Quota (Giới hạn tối đa)** | `max-elastic-ips = 5` | `VERIFIED` | Quota tài khoản cho phép tối đa 5 EIPs. |
| **EIP Đang sử dụng** | `allocated = 0` | `VERIFIED` | Còn nguyên 5 EIPs trống, đủ cho 2 EIPs của dự án. |
| **Quyền AllocateAddress (EIP)** | `ec2:AllocateAddress` | `NOT VERIFIED` | Chưa gọi lệnh cấp phát thật; sẽ kiểm chứng tại Gate 1. |
| **IAM Instance Profile** | Tồn tại `LabInstanceProfile` | `VERIFIED` | Đã kiểm tra qua `iam.get_instance_profile()`, gắn sẵn role `LabRole`. |
| **IAM Service Role** | Tồn tại `LabRole` | `VERIFIED` | Đã kiểm tra qua `iam.get_role()`, tồn tại sẵn trong Lab. |
| **Quyền tạo S3 Bucket** | `s3:CreateBucket` | `NOT VERIFIED` | Lệnh `s3:ListAllMyBuckets` bị Deny bởi policy `voc-cancel-cred`; quyền tạo bucket cụ thể sẽ được kiểm chứng khi chạy `bootstrap apply`. |
| **Quyền tạo RDS** | `rds:CreateDBInstance` | `NOT VERIFIED` | Sẽ được kiểm chứng khi chạy `terraform apply` cho RDS. |
| **Kết nối SSM Session Manager** | SSM Agent kết nối AWS SSM | `NOT VERIFIED` | Cần máy ảo EC2 khởi động thực tế mới kiểm chứng được endpoint SSM. |

---

## 6. Kết Luận Gate 0 Preflight (Work Package P2-01)

* [x] **Xác minh chỉ đọc:** Vùng `us-east-1`, 2 AZs `us-east-1a`/`us-east-1b`, các loại máy ảo `t3.medium`, `t3.large`, RDS `db.t3.micro` và profile `LabInstanceProfile` đều tồn tại và khả dụng.
* [ ] **Quyền thao tác tạo tài nguyên:** Được ghi nhận là `NOT VERIFIED` cho đến khi chạy lệnh apply có kiểm soát tại P2-02 và P2-05.
* [ ] **Trạng thái Gate 0:** Đạt điều kiện kỹ thuật để tiến hành soạn thảo mã nguồn IaC và trình Thành viên 2 phản biện; **chưa tự ý cấp phép `terraform apply`**.
