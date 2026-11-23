# KẾ HOẠCH DỰ TOÁN NGÂN SÁCH VÀ QUẢN LÝ CHI PHÍ LAB (PHASE 2)

> **Dự án:** Tự động hóa triển khai ứng dụng 2-Tier theo DevSecOps/GitOps trên AWS  
> **Thực hiện:** Thành viên 1 (Cloud Infrastructure & Platform Engineer)  
> **Khu vực áp dụng:** `us-east-1` (US East - N. Virginia)  
> **Đơn vị tiền tệ:** USD ($)  
> **Ngày cập nhật:** 23/11/2026 (Tính toán chuẩn xác 130GB EBS, 3 Public IPv4 và chính sách chi phí khi stopped)  

---

## 1. Bảng Chi Tiết Dự Toán Chi Phí Hạ Tầng AWS (On-Demand)

| Tài nguyên | Thông số kỹ thuật | Số lượng | Đơn giá AWS (`us-east-1`) | Chi phí theo giờ ($/h) | Chi phí cho 20 giờ Lab ($) |
|---|---|---|---|---|---|
| **EC2 Harbor** | `t3.medium` (2 vCPU, 4GB RAM) | 1 | $0.0416 / giờ | $0.0416 | $0.832 |
| **EC2 K3s Server** | `t3.medium` (2 vCPU, 4GB RAM) | 1 | $0.0416 / giờ | $0.0416 | $0.832 |
| **EC2 K3s Worker** | `t3.large` (2 vCPU, 8GB RAM) | 1 | $0.0832 / giờ | $0.0832 | $1.664 |
| **RDS PostgreSQL** | `db.t3.micro` (Single-AZ, 1 vCPU, 1GB RAM) | 1 | $0.0180 / giờ | $0.0180 | $0.360 |
| **Public IPv4 (Harbor EIP)** | Elastic IP gắn vào EC2 Harbor | 1 | $0.0050 / giờ | $0.0050 | $0.100 |
| **Public IPv4 (Server EIP)** | Elastic IP gắn vào K3s Server | 1 | $0.0050 / giờ | $0.0050 | $0.100 |
| **Public IPv4 (Worker IP)** | Public IP tự động gắn cho K3s Worker | 1 | $0.0050 / giờ | $0.0050 | $0.100 |
| **EBS gp3 Storage (EC2)** | **130 GB gp3** (Chi tiết bên dưới) | 130 GB | $0.0800 / GB-tháng | ~$0.0142 / giờ | ~$0.285 (20h) / $3.47 (10 ngày) |
| **RDS gp3 Storage** | 20 GB gp3 cho PostgreSQL | 20 GB | $0.1150 / GB-tháng | ~$0.0032 / giờ | ~$0.064 (20h) / $0.77 (10 ngày) |
| **S3 State Storage** | S3 Bucket bootstrap (< 100 MB) | 1 | $0.0230 / GB-tháng | Không đáng kể | < $0.010 |

---

## 2. Chi Tiết Phân Bổ 130 GB EBS gp3

Tổng dung lượng ổ cứng EBS trong toàn bộ hệ thống là **130 GB gp3**, phân bổ như sau:
* **EC2 Harbor Root Volume:** 20 GB gp3 (Hệ điều hành Ubuntu 22.04 LTS).
* **EC2 Harbor Dedicated Data Volume:** **60 GB gp3** (Gắn tại `/dev/xvdf`, mount `/data` cho container registry và Trivy DB).
* **EC2 K3s Server Root Volume:** 20 GB gp3 (Hệ điều hành + SQLite database K3s).
* **EC2 K3s Worker Root Volume:** 30 GB gp3 (Hệ điều hành + Docker/containerd images + FastAPI Pods).
* **TỔNG CỘNG: 20 + 60 + 20 + 30 = 130 GB gp3.**

*Chi phí lưu trữ 130 GB EBS:*
* Tính theo tháng (30 ngày): $130 \times 0.08 = \mathbf{\$10.40 / \text{tháng}}$.
* Tính theo ngày: $\$10.40 / 30 = \mathbf{\$0.347 / \text{ngày}}$.

---

## 3. Tổng Hợp Ngân Sách Dự Kiến

* **Chi phí vận hành hệ thống khi ĐANG CHẠY (Running):**
  $$\text{Compute } (\$0.1844) + \text{IPv4 (3 IPs) } (\$0.0150) + \text{Storage } (\$0.0174) \approx \mathbf{\$0.2168 / \text{giờ}}$$
* **Tổng chi phí ước tính cho 20 giờ thực hành Lab thực tế:**
  $$\text{Phí vận hành 20h } (20 \times \$0.2168 = \$4.34) + \text{Phí lưu trữ ổ đĩa 10 ngày Lab } (\$4.24) \approx \mathbf{\$8.50 - \$10.00 USD}$$
* **Hạn mức AWS Academy:** Tài khoản Learner Lab cấp **$100.00 USD**. Dự toán chi phí Phase 2 chiếm **dưới 10%** tổng ngân sách được cấp, hoàn toàn an toàn và nằm trong ngưỡng kiểm soát.

---

## 4. Chính Sách Chi Phí Khi Hệ Thống Ở Trạng Thái DỪNG (STOPPED)

> [!WARNING]
> **Hiểu đúng về việc tính phí khi Stop Instance:** Dừng máy ảo (Stop) giúp ngắt phí tính toán (Compute), nhưng **KHÔNG NGỪNG TẤT CẢ CÁC KHOẢN PHÍ KHÁC**.

1. **Chi phí Compute (vCPU & RAM):**
   - EC2 instances và RDS instance: Giảm về **$0.00 / giờ** khi ở trạng thái `stopped`.
2. **Chi phí Lưu trữ Ổ cứng (EBS & RDS Storage):**
   - **VẪN TIẾP TỤC BỊ TÍNH PHÍ** vì dữ liệu vẫn được lưu trên ổ đĩa AWS ($10.40/tháng cho 130GB EBS và $2.30/tháng cho 20GB RDS).
3. **Chi phí Địa chỉ Public IPv4 / Elastic IP khi Stop:**
   - **Public IP của Worker:** Tự động giải phóng khi Stop instance $\rightarrow$ **Không tốn phí** khi stop.
   - **2 Elastic IPs (Harbor & K3s Server):** Khi máy chủ gắn EIP bị STOP, EIP chuyển sang trạng thái *unassociated / idle* $\rightarrow$ **AWS vẫn tính phí $0.005 / IP / giờ** ($0.24 / ngày cho 2 EIPs).
4. **Quy tắc tự động bật của RDS:**
   - Theo cơ chế mặc định của AWS, một RDS instance bị Stop sẽ **tự động khởi động lại sau 7 ngày liên tục** để áp dụng cập nhật bảo trì. Quản trị viên cần chú ý kiểm tra trước mốc 7 ngày.

---

## 5. Chiến Lược Tiết Kiệm Chi Phí & Kế Hoạch Teardown

1. **Sau mỗi buổi học:** Chạy script stop 3 EC2 instances và stop RDS instance theo `runbook.md`.
2. **Giải phóng triệt để:** Nếu nghỉ giữa các Phase quá 3 ngày mà không thực hành, cân nhắc snapshot RDS và destroy tạm hạ tầng để tránh mất phí lưu trữ $0.42/ngày.
3. **Kết thúc Phase 2:** Sau khi được nghiệm thu đầy đủ, thực hiện `terraform destroy` theo quy trình được phê duyệt để giải phóng 100% tài nguyên và EIPs.
