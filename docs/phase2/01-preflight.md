# P2-01 — BÁO CÁO AWS PREFLIGHT, NGÂN SÁCH VÀ QUYỀN HẠN LAB

> **Dự án:** Tự động hóa triển khai ứng dụng 2-Tier theo DevSecOps/GitOps trên AWS  
> **Thực hiện:** Thành viên 1 (Cloud Infrastructure & Platform Engineer)  
> **Ngày thực hiện kiểm tra:** 22/11/2026 lúc 22:17 (Giờ VN)  
> **Tài liệu tham chiếu:** `PHASE2.md` v1.0, Work Package P2-01  
> **Trạng thái Gate 0:** `PASS` (Đã xác minh toàn bộ điều kiện hạ tầng thực tế trên AWS Academy)  

---

## 1. Thông tin Phiên làm việc và Danh tính AWS (Caller Identity)

| Thông số | Giá trị thực tế từ AWS CLI / SDK | Trạng thái | Ghi chú |
|---|---|---|---|
| **AWS Account ID** | `645921******` (Đã che bảo mật) | `PASS` | Tài khoản AWS Academy Learner Lab |
| **IAM User / Role** | `voclabs/user5436930=23521306@gm.uit.edu.vn` | `PASS` | Role sinh viên được cấp phép |
| **Caller ARN** | `arn:aws:sts::645921******:assumed-role/voclabs/...` | `PASS` | Xác thực thành công qua STS |
| **Default Region** | `us-east-1` (US East - N. Virginia) | `PASS` | Vùng mặc định có đầy đủ tính năng nhất |

---

## 2. Kết Quả Kiểm Tra Availability Zones (AZ) Khả Dụng

Lệnh kiểm tra: `ec2.describe_availability_zones(State='available')`  
Khu vực `us-east-1` có đủ **6 Availability Zones** đều ở trạng thái `available`:

| AZ Name | Zone ID | Trạng thái | Lựa chọn kiến trúc cho VPC |
|---|---|---|---|
| `us-east-1a` | `use1-az6` | `available` | **CHỌN LÀM AZ 1** (Public Subnet 1 + Private DB Subnet 1) |
| `us-east-1b` | `use1-az1` | `available` | **CHỌN LÀM AZ 2** (Public Subnet 2 + Private DB Subnet 2) |
| `us-east-1c` | `use1-az2` | `available` | Dự phòng |
| `us-east-1d` | `use1-az4` | `available` | Dự phòng |
| `us-east-1e` | `use1-az3` | `available` | Không có offering t3 |
| `us-east-1f` | `use1-az5` | `available` | Dự phòng |

---

## 3. Kết Quả Kiểm Tra EC2 Instance Offerings (`t3.medium`, `t3.large`)

Lệnh kiểm tra: `ec2.describe_instance_type_offerings(LocationType='availability-zone')`  
Cả hai loại instance theo thiết kế của `PHASE2.md` đều được hỗ trợ đầy đủ tại 2 AZ được chọn:

| Instance Type | vCPU | RAM | Mục đích sử dụng | Khả dụng tại `us-east-1a` | Khả dụng tại `us-east-1b` | Trạng thái |
|---|---|---|---|---|---|---|
| `t3.medium` | 2 | 4 GiB | EC2 Harbor Registry | **CÓ** | **CÓ** | `PASS` |
| `t3.medium` | 2 | 4 GiB | EC2 K3s Control Plane Server | **CÓ** | **CÓ** | `PASS` |
| `t3.large` | 2 | 8 GiB | EC2 K3s Worker Node | **CÓ** | **CÓ** | `PASS` |

---

## 4. Kết Quả Kiểm Tra RDS PostgreSQL 16 Offerings

Lệnh kiểm tra: `rds.describe_orderable_db_instance_options(Engine='postgres')`  
Hệ thống tìm thấy **56 tùy chọn cấu hình hợp lệ** cho PostgreSQL 16:
* **Các instance class khả dụng:** Cả `db.t4g.micro` (ARM/Graviton2) và `db.t3.micro` (x86_64).
* **Phiên bản Engine:** Hỗ trợ PostgreSQL `16.9` (và các bản 16.x).
* **Storage Type:** Hỗ trợ chuẩn `gp3` (và gp2, io1, io2).
* **Lựa chọn triển khai:** `db.t3.micro`, Engine PostgreSQL 16.x, Storage 20GB gp3, `Single-AZ` (không MultiAZ) để tối ưu chi phí và tài nguyên lab.
* **Trạng thái:** `PASS`

---

## 5. Kết Quả Kiểm Tra Quota Elastic IP và IAM Role

| Hạng mục | Hạn mức cho phép (Quota) | Hiện trạng sử dụng | Nhu cầu dự án | Trạng thái |
|---|---|---|---|---|
| **Max Elastic IPs (EIP)** | **5** IPs | **0** IP đang dùng | Cần **2** IPs (Harbor & K3s Server) | `PASS` |
| **IAM Instance Profile** | Tồn tại `LabInstanceProfile` | Gắn sẵn role `LabRole` | Gắn vào EC2 để quản trị qua SSM | `PASS` |
| **IAM Service Role** | Tồn tại `LabRole` | Quyền hạn rộng trong lab | Dùng tham chiếu cho tài nguyên AWS | `PASS` |

*Ghi chú quan trọng:* Do AWS Academy cấm quyền tạo mới IAM Role (`iam:CreateRole`), việc xác nhận `LabInstanceProfile` và `LabRole` tồn tại cho phép chúng ta tham chiếu trực tiếp vào cấu hình EC2 Terraform mà không bị lỗi `AccessDenied`.

---

## 6. Kết Luận Gate 0 (Work Package P2-01)

* [x] **Account & Region:** Xác nhận tài khoản hợp lệ tại `us-east-1`.
* [x] **AZ Mapping:** Đã chốt `us-east-1a` và `us-east-1b` (loại bỏ hoàn toàn rủi ro hardcode sai AZ).
* [x] **Instance Offerings:** Đảm bảo 100% có sẵn `t3.medium`, `t3.large` và RDS PostgreSQL 16 `db.t3.micro`.
* [x] **Quota & IAM:** Quota EIP còn nguyên 5/5, role `LabRole` và profile `LabInstanceProfile` sẵn sàng.
* [x] **Quyết định:** **CHÍNH THỨC THÔNG QUA GATE 0 (PASS)**. Đủ điều kiện tiến hành viết mã nguồn Terraform và Ansible (P2-02, P2-03, P2-04, P2-06).
