# P2-02 — BÁO CÁO KIỂM ĐỊNH S3 REMOTE STATE VÀ STATE LOCKING

> **Dự án:** Tự động hóa triển khai ứng dụng 2-Tier theo DevSecOps/GitOps trên AWS  
> **Thực hiện:** Thành viên 1 (Cloud Infrastructure & Platform Engineer)  
> **Ngày lập:** 22/11/2026  
> **Tài liệu tham chiếu:** `PHASE2.md` v1.0, Work Package P2-02  
> **Trạng thái kiểm định Offline:** `PASS` (Cú pháp, Backend, Lockfile đạt chuẩn)  
> **Trạng thái AWS Runtime:** `NOT APPLIED` (Chưa khởi tạo bucket trên AWS thực tế)  

---

## 1. Thiết Kế S3 Remote State & Native Locking

Terraform 1.11+ chính thức hỗ trợ **S3 Native State Locking** thông qua cơ chế S3 Conditional Writes (`use_lockfile = true`), loại bỏ hoàn toàn sự phụ thuộc vào bảng DynamoDB.

### 1.1. Module Bootstrap (`bootstrap/main.tf`)
- **Bucket Name:** `devops-lab-tfstate-us-east-1` (Toàn cục duy nhất).
- **Versioning:** Bật `Enabled` trên `aws_s3_bucket_versioning` để bảo vệ lịch sử state và hỗ trợ rollback khi gặp sự cố.
- **Mã hóa (Encryption):** Sử dụng SSE-S3 (`AES256`) mặc định qua `aws_s3_bucket_server_side_encryption_configuration`, không tốn chi phí quản lý AWS KMS.
- **Chặn truy cập công khai (Public Access Block):** Kích hoạt toàn bộ 4 cờ bảo vệ:
  + `block_public_acls = true`
  + `block_public_policy = true`
  + `ignore_public_acls = true`
  + `restrict_public_buckets = true`
- **Bảo vệ xóa nhầm:** `force_destroy = false`.

### 1.2. Cấu hình Backend (`terraform/backend.tf`)
```hcl
terraform {
  required_version = ">= 1.11.0"

  backend "s3" {
    bucket       = "devops-lab-tfstate-us-east-1"
    key          = "infrastructure/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # S3 Native State Locking (Terraform >= 1.11)
  }
}
```

---

## 2. Ghim Phiên Bản Công Cụ & Provider Lockfile

- **Terraform Core:** `>= 1.11.0` (Hiện kiểm định tại v1.17.0).
- **AWS Provider:** Ghim `>= 5.30.0` trong `versions.tf`.
- **Lockfile `.terraform.lock.hcl`:** Đã khởi tạo và ghim chính xác `hashicorp/aws v6.73.0` cho cả thư mục `terraform/` và `bootstrap/`.

---

## 3. Kết Quả Kiểm Tra Offline (PowerShell)

| Thao tác kiểm tra | Thư mục | Lệnh thực thi | Kết quả | Ghi chú |
|---|---|---|---|---|
| **Định dạng code** | Root | `terraform fmt -check -recursive` | `PASS` (Exit code 0) | 100% file `.tf` chuẩn HCL |
| **Khởi tạo Bootstrap** | `bootstrap/` | `terraform init -backend=false -input=false` | `PASS` (Exit code 0) | Provider lock hợp lệ |
| **Validate Bootstrap** | `bootstrap/` | `terraform validate` | `Success! The configuration is valid.` | Cú pháp hợp lệ |
| **Khởi tạo Root** | `terraform/` | `terraform init -backend=false -input=false` | `PASS` (Exit code 0) | 5 modules tải thành công |
| **Validate Root** | `terraform/` | `terraform validate` | `Success! The configuration is valid.` | Toàn bộ liên kết module khớp 100% |

---

## 4. Nguyên Tắc & Quy Trình Áp Dụng (Runbook Sắp Tới)

1. Khi được phép từ nhóm và tài khoản Lab sẵn sàng, chạy khởi tạo S3 Bucket trước:
   ```powershell
   cd bootstrap
   terraform apply
   ```
2. Sau khi bucket tồn tại, mới chuyển sang `terraform/` để chạy `terraform init` (chuyển từ local sang S3 remote backend).
3. Tuyệt đối không chạy `terraform apply -lock=false`.
