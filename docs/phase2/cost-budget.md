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

* **Chi phí vận hành hệ thống khi ĐANG CHẠY (Running - theo giờ):**
  $$\text{Compute } (\$0.1844) + \text{IPv4 (3 IPs) } (\$0.0150) \approx \mathbf{\$0.1994 / \text{giờ}}$$
  *(Chi phí lưu trữ ổ cứng tính theo ngày/tháng liên tục, không cộng dồn hai lần vào giờ chạy).*

* **Bóc tách chi phí toàn diện cho kịch bản Lab 10 ngày (20 giờ chạy, 220 giờ dừng):**
  1. **Chi phí Compute (20 giờ chạy thực hành):**
     $$20 \text{ giờ} \times \$0.1844 = \mathbf{\$3.69 \text{ USD}}$$
  2. **Chi phí Public IPv4 trong 20 giờ chạy (3 IPs):**
     $$20 \text{ giờ} \times 3 \text{ IPs} \times \$0.0050 = \mathbf{\$0.30 \text{ USD}}$$
  3. **Chi phí duy trì 2 Elastic IPs trong 220 giờ dừng (Harbor & Server EIPs):**
     $$220 \text{ giờ} \times 2 \text{ EIPs} \times \$0.0050 = \mathbf{\$2.20 \text{ USD}}$$
     *(Theo chính sách AWS từ 01/02/2024, Elastic IP gắn vào instance đang dừng vẫn bị tính phí $0.005/h; Public IP tự cấp của Worker được thu hồi khi dừng nên $0.00).*
  4. **Chi phí Lưu trữ Cố định Toàn kỳ 10 ngày (Storage):**
     $$\text{EBS 130 GB } (\$3.47) + \text{RDS 20 GB } (\$0.77) + \text{S3 } (< \$0.01) = \mathbf{\$4.24 \text{ USD}}$$
  5. **Dự phòng Data Transfer & RDS Snapshots/Backups:**
     $$\text{Data Transfer (Docker pull, OS updates, Trivy DB) + Snapshots} \approx \mathbf{\$1.00 - \$1.50 \text{ USD}}$$

* **TỔNG CHI PHÍ DỰ KIẾN TOÀN KỲ:**
  $$\$3.69 + \$0.30 + \$2.20 + \$4.24 + \$1.00 \approx \mathbf{\$11.43 - \$12.00 \text{ USD}}$$
* **Đánh giá Hạn mức AWS Academy:** Tài khoản Learner Lab cấp **$100.00 USD**. Dự toán chi phí Phase 2 chiếm khoảng **11.5% - 12.0%** tổng ngân sách được cấp. Ngân sách đảm bảo khả thi nhưng cần quản lý chặt chẽ theo Runbook, tránh để quên tài nguyên không stop.

---

## 4. Chính Sách Chi Phí Khi Hệ Thống Ở Trạng Thái DỪNG (STOPPED)

> [!WARNING]
> **Hiểu đúng về việc tính phí khi Stop Instance:** Dừng máy ảo (Stop) giúp ngắt phí tính toán (Compute), nhưng **KHÔNG NGỪNG TẤT CẢ CÁC KHOẢN PHÍ KHÁC**.

1. **Chi phí Compute (vCPU & RAM):**
   - EC2 instances và RDS instance: Giảm về **$0.00 / giờ** khi ở trạng thái `stopped`.
2. **Chi phí Lưu trữ Ổ cứng (EBS & RDS Storage):**
   - **VẪN TIẾP TỤC BỊ TÍNH PHÍ** vì dữ liệu vẫn được lưu trên ổ đĩa AWS ($10.40/tháng cho 130GB EBS và $2.30/tháng cho 20GB RDS, tương đương ~$0.424/ngày).
3. **Chi phí Địa chỉ Public IPv4 / Elastic IP khi Stop:**
   - **Public IP của Worker:** Tự động giải phóng khi Stop instance $\rightarrow$ **Không tốn phí** khi stop.
   - **2 Elastic IPs (Harbor & K3s Server):** Kể từ 01/02/2024, AWS tính phí **$0.005 / IP / giờ** cho tất cả Public IPv4 in-use. Khi máy chủ dừng, EIP vẫn gắn với ENI của instance $\rightarrow$ **AWS vẫn tiếp tục tính phí $0.005 / IP / giờ** ($0.24 / ngày cho 2 EIPs, tức ~$2.20 cho 220 giờ dừng).
4. **Quy tắc tự động bật của RDS:**
   - Theo cơ chế mặc định của AWS, một RDS instance bị Stop sẽ **tự động khởi động lại sau 7 ngày liên tục** để áp dụng cập nhật bảo trì. Quản trị viên cần chú ý kiểm tra trước mốc 7 ngày.

---

## 5. Chiến Lược Tiết Kiệm Chi Phí & Kế Hoạch Teardown

1. **Sau mỗi buổi học:** Chạy script stop 3 EC2 instances và stop RDS instance theo `runbook.md`.
2. **Giải phóng triệt để:** Nếu nghỉ giữa các Phase quá 3 ngày mà không thực hành, cân nhắc snapshot RDS và destroy tạm hạ tầng để tránh mất phí lưu trữ $0.42/ngày.
3. **Kết thúc Phase 2:** Sau khi được nghiệm thu đầy đủ, thực hiện `terraform destroy` theo quy trình được phê duyệt để giải phóng 100% tài nguyên và EIPs.
