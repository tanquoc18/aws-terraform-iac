# P2-07 — BÁO CÁO TRIỂN KHAI HARBOR HTTPS REGISTRY TRÊN EBS 60GB

> **Dự án:** Tự động hóa triển khai ứng dụng 2-Tier theo DevSecOps/GitOps trên AWS  
> **Thực hiện:** Thành viên 1 & Thành viên 2  
> **Ngày lập:** 22/11/2026  
> **Tài liệu tham chiếu:** `PHASE2.md` v1.0, Work Package P2-07  
> **Trạng thái:** `READY_FOR_EXECUTION`  

---

## 1. Kiến Trúc Lưu Trữ & Tên Miền Harbor

- **Máy chủ:** EC2 `t3.medium` tại Public Subnet 2.
- **Lưu trữ chuyên dụng:** Gắn ổ cứng EBS **60GB gp3** (`/dev/xvdf`) định dạng `ext4` và mount vào thư mục `/data`.
- **Domain Wildcard:** `hub.<HARBOR_EIP>.nip.io` phân giải trực tiếp về Elastic IP của Harbor.
- **Private VPC Route:** K3s Server và Worker tự động ánh xạ `hub.<HARBOR_EIP>.nip.io` về Private IP nội bộ của Harbor (`10.0.2.x`) trong `/etc/hosts` để kéo image siêu tốc và không tốn băng thông Internet.

---

## 2. Chiến Lược Chứng Chỉ TLS & Root CA Trust

> [!IMPORTANT]
> **Tuyệt đối không sử dụng cờ `--insecure-registry`** trong môi trường DevSecOps.

1. **Sinh Private Root CA:**
   - Tạo CA nội bộ tại `/data/cert/ca.key` và `/data/cert/ca.crt` (Thời hạn 365 ngày).
2. **Khai báo Subject Alternative Names (SAN) hợp lệ:**
   - `DNS.1 = hub.<HARBOR_EIP>.nip.io`
   - `IP.1 = <HARBOR_PRIVATE_IP>`
   - `IP.2 = <HARBOR_EIP>`
3. **Phân phối Root CA:**
   - Root CA (`ca.crt`) được Ansible tự động fetch về máy điều khiển và phân phối vào:
     + `/usr/local/share/ca-certificates/harbor-ca.crt` (chạy `update-ca-certificates`).
     + `/etc/rancher/k3s/registries.yaml` trên cả K3s Server và Worker.

---

## 3. Các Bước Kiểm Chứng Harbor Registry

1. **Kiểm tra trạng thái Service & Container:**
   ```bash
   docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
   # Kỳ vọng: harbor-core, harbor-db, harbor-portal, registry, trivy đều Up (healthy)
   ```
2. **Kiểm tra Health API qua HTTPS:**
   ```bash
   curl -k https://127.0.0.1/api/v2.0/ping
   # Kỳ vọng: HTTP 200 "pong"
   ```
3. **Thử nghiệm Push Image bằng Docker CLI:**
   ```bash
   docker login hub.<HARBOR_EIP>.nip.io -u admin -p Harbor12345!
   docker tag python:3.11-slim hub.<HARBOR_EIP>.nip.io/library/test:v1
   docker push hub.<HARBOR_EIP>.nip.io/library/test:v1
   ```
