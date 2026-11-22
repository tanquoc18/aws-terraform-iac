# KẾ HOẠCH DỰ TOÁN NGÂN SÁCH VÀ QUẢN LÝ CHI PHÍ LAB (PHASE 2)

> **Dự án:** Tự động hóa triển khai ứng dụng 2-Tier theo DevSecOps/GitOps trên AWS  
> **Thực hiện:** Thành viên 1 (Cloud Infrastructure & Platform Engineer)  
> **Khu vực dự kiến:** `us-east-1` (hoặc vùng Lab chỉ định)  
> **Đơn vị tiền tệ:** USD ($)  

---

## 1. Bảng Ước Tính Chi Phí Hạ Tầng AWS (Dựa trên On-Demand Pricing)

| Tài nguyên | Thông số kỹ thuật | Số lượng | Đơn giá ước tính | Chi phí theo giờ ($/h) | Chi phí cho 20 giờ Lab ($) |
|---|---|---|---|---|---|
| **EC2 Harbor** | `t3.medium` (2 vCPU, 4GB RAM) | 1 | $0.0416 / giờ | $0.0416 | $0.832 |
| **EC2 K3s Server** | `t3.medium` (2 vCPU, 4GB RAM) | 1 | $0.0416 / giờ | $0.0416 | $0.832 |
| **EC2 K3s Worker** | `t3.large` (2 vCPU, 8GB RAM) | 1 | $0.0832 / giờ | $0.0832 | $1.664 |
| **RDS PostgreSQL** | `db.t4g.micro` (hoặc `db.t3.micro`) | 1 | ~$0.0180 / giờ | $0.0180 | $0.360 |
| **Elastic IP (In-use)** | Public IPv4 gắn vào EC2 đang chạy | 2 | $0.0050 / IP / giờ | $0.0100 | $0.200 |
| **EBS gp3 Storage** | 60GB (Harbor) + 3x20GB (Root OS) = 120GB | 120 GB | $0.08 / GB-tháng | ~$0.0133 / ngày | ~$0.320 (cả tháng) |
| **RDS Storage** | 20GB gp3 | 20 GB | $0.115 / GB-tháng | ~$0.0076 / ngày | ~$0.076 (10 ngày) |
| **S3 State Storage** | Bootstrap bucket (< 100 MB) | 1 | $0.023 / GB-tháng | Không đáng kể | < $0.010 |

---

## 2. Tổng Hợp Ngân Sách Dự Kiến

* **Chi phí vận hành theo giờ:** **~$0.1944 / giờ** (chưa đến $0.20 mỗi giờ toàn bộ hệ thống hoạt động).
* **Tổng chi phí dự kiến cho toàn bộ quá trình Lab Phase 2 (khoảng 20 - 30 giờ thực tế):** **~$4.00 - $6.50 USD**.
* **Đánh giá hạn mức AWS Academy:** Thông thường tài khoản AWS Academy cấp ngân sách $100.00 USD. Dự toán chi phí Phase 2 chiếm **dưới 7%** tổng ngân sách được cấp, hoàn toàn an toàn và nằm trong hạn mức.

---

## 3. Chiến Lược Kiểm Soát Chi Phí và Phòng Ngừa Phát Sinh

1. **Ngăn chặn rò rỉ phí Public IPv4:**
   - Chỉ cấp phát đúng 2 Elastic IPs theo thiết kế (Harbor và K3s Server).
   - Tuyệt đối không giữ EIP ở trạng thái không gắn (unassociated) vì AWS sẽ phạt phí cao hơn.
2. **Quy tắc tắt máy sau phiên thực hành (Stop Instances):**
   - Khi không làm việc, tắt (Stop) cả 3 EC2 instances và tạm dừng (Stop) RDS instance để không bị tính phí tính toán (compute).
3. **Giám sát số dư định kỳ:**
   - Trước và sau mỗi buổi thực hành, kiểm tra số dư còn lại tại thanh công cụ AWS Academy.
4. **Quy trình Teardown dọn dẹp cuối Phase 2:**
   - Sau khi hoàn thành nghiệm thu (Gate 2) và xuất báo cáo có chữ ký của cả 2 thành viên, thực hiện `terraform destroy` toàn bộ hạ tầng để giải phóng triệt để tài nguyên.
