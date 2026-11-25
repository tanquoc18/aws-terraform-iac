# RUNBOOK QUẢN TRỊ HẠ TẦNG VÀ TIẾT KIỆM CHI PHÍ (PHASE 2)

> **Dự án:** Tự động hóa triển khai ứng dụng 2-Tier theo DevSecOps/GitOps trên AWS  
> **Thực hiện:** Thành viên 1 (Cloud Infrastructure & Platform Engineer)  
> **Áp dụng cho:** Môi trường AWS Academy Learner Lab  
> **Ngày lập:** 22/11/2026  

---

## 1. Quy Trình Khởi Động & Tắt Lab Hàng Ngày (Tiết Kiệm Chi Phí)

Mỗi buổi thực hành kết thúc, việc duy trì EC2 và RDS ở trạng thái chạy sẽ làm cạn kiệt ngân sách $100 của tài khoản Lab. Hãy thực hiện đúng quy trình 2 bước sau:

### 1.1. Khi Tạm Dừng Phiên Làm Việc (Stop Lab)
1. **Dừng 3 máy chủ EC2 (Dừng tính phí vCPU/RAM):**
   ```powershell
   aws ec2 stop-instances --instance-ids $(aws ec2 describe-instances --filters "Name=tag:Project,Values=devops-2tier" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].InstanceId" --output text)
   ```
2. **Tạm dừng RDS Database Instance:**
   ```powershell
   aws rds stop-db-instance --db-instance-identifier devops-2tier-rds
   ```
3. **Bấm "Stop Lab" trên giao diện AWS Academy.**

### 1.2. Khi Bắt Đầu Lại Phiên Làm Việc (Start Lab)
1. **Bấm "Start Lab" trên AWS Academy** và chờ đèn xanh.
2. **Khởi động lại RDS Database:**
   ```powershell
   aws rds start-db-instance --db-instance-identifier devops-2tier-rds
   ```
3. **Khởi động lại 3 máy chủ EC2:**
   ```powershell
   aws ec2 start-instances --instance-ids $(aws ec2 describe-instances --filters "Name=tag:Project,Values=devops-2tier" "Name=instance-state-name,Values=stopped" --query "Reservations[*].Instances[*].InstanceId" --output text)
   ```
   *(Do Harbor và K3s Server sử dụng Elastic IP cố định, IP Public và tên miền `nip.io` hoàn toàn không bị thay đổi sau khi khởi động lại).
> [!IMPORTANT]
> **Lưu ý chi phí Elastic IP khi Stop:** Kể từ 01/02/2024, AWS tính phí **$0.005/giờ/EIP** cho cả Elastic IP gắn với EC2 đang ở trạng thái stopped (~$0.24/ngày cho 2 EIPs). Do đó, khi nghỉ Lab dài ngày (> 3 ngày), nên giải phóng hoặc teardown theo quy định để tiết kiệm tối đa ngân sách.*

---

## 2. Quy Trình Sao Lưu Dữ Liệu Cụm K3s (SQLite Datastore & Token)

K3s Server lưu trữ toàn bộ trạng thái cluster trong cơ sở dữ liệu SQLite cục bộ tại `/var/lib/rancher/k3s/server/db/`.

### 2.1. Lệnh Sao Lưu Cụm K3s
Thực hiện trên máy chủ K3s Server:
```bash
# 1. Tạo thư mục chứa bản backup
sudo mkdir -p /opt/k3s-backup

# 2. Tạo snapshot dữ liệu SQLite an toàn (sử dụng sqlite3 online backup để tránh rách giao dịch)
sudo sqlite3 /var/lib/rancher/k3s/server/db/state.db ".backup '/opt/k3s-backup/state-$(date +%Y%m%d).db'"
# Hoặc dừng service tạm thời nếu sao lưu bằng lệnh cp:
# sudo systemctl stop k3s && sudo cp /var/lib/rancher/k3s/server/db/state.db /opt/k3s-backup/ && sudo systemctl start k3s

# 3. Sao lưu token xác thực của cụm
sudo cp /var/lib/rancher/k3s/server/node-token /opt/k3s-backup/node-token.bak

# 4. Sao lưu cấu hình CA trust
sudo cp /etc/rancher/k3s/registries.yaml /opt/k3s-backup/registries.yaml.bak
```

### 2.2. Quy Trình Phục Hồi Khi Gặp Sự Cố
```bash
sudo systemctl stop k3s
sudo cp /opt/k3s-backup/state-YYYYMMDD.db /var/lib/rancher/k3s/server/db/state.db
sudo systemctl start k3s
```

---

## 3. Quy Trình Teardown Dọn Dẹp Có Kiểm Soát (Cuối Phase 2)

> [!CAUTION]
> **Tuyệt đối không tự ý chạy `terraform destroy` khi chưa có chữ ký nghiệm thu chung của cả 2 thành viên.**

Khi cả 2 thành viên đã hoàn thành và lưu trữ đầy đủ bằng chứng nghiệm thu (Gate 2):
1. **Chụp Snapshot thủ công cho RDS (nếu cần giữ dữ liệu):**
   ```powershell
   aws rds create-db-snapshot --db-instance-identifier devops-2tier-rds --db-snapshot-identifier devops-2tier-rds-final-snapshot
   ```
2. **Thực thi hủy tài nguyên qua Terraform:**
   ```powershell
   Set-Location terraform
   terraform destroy  # Xác nhận Yes khi được cả 2 thành viên duyệt
   ```
3. **Kiểm tra giải phóng Elastic IPs:**
   Đảm bảo toàn bộ 2 EIPs đã được release, không còn tài nguyên nào treo phát sinh phí.
4. **Giữ lại S3 State Bucket trong `bootstrap/`** để lưu trữ lịch sử state, chỉ destroy `bootstrap/` khi kết thúc toàn bộ môn học/đồ án.
