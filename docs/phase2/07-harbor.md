# P2-07 — BÁO CÁO TRIỂN KHAI HARBOR HTTPS REGISTRY TRÊN EBS 60GB

> **Dự án:** Tự động hóa triển khai ứng dụng 2-Tier theo DevSecOps/GitOps trên AWS  
> **Thực hiện:** Thành viên 1 (Cloud Infrastructure & Platform Engineer)  
> **Ngày lập:** 22/11/2026 (Cập nhật đối chiếu review: 23/11/2026)  
> **Tài liệu tham chiếu:** `PHASE2.md` v1.0, Work Package P2-07  
> **Trạng thái:** `CODE_IMPLEMENTED_AND_VALIDATED` (Sẵn sàng triển khai khi Gate 1 được duyệt)  

---

## 1. Kiến Trúc Lưu Trữ & Tên Miền Harbor

- **Máy chủ:** EC2 `t3.medium` tại Public Subnet 2.
- **Lưu trữ chuyên dụng:** Gắn ổ cứng EBS **60GB gp3** định dạng `ext4` và mount vào thư mục `/data`. Script Ansible tự động nhận diện chính xác thiết bị theo EBS Volume ID (`vol-xxxx`) do Terraform xuất ra (tuân thủ tài liệu AWS `identify-nvme-ebs-device`), kiểm tra kích thước ~60GB và xác nhận không phải ổ root trước khi format/mount, bảo đảm fail-closed an toàn tuyệt đối.
- **Domain Wildcard:** `hub.<HARBOR_EIP>.nip.io` phân giải trực tiếp về Elastic IP của Harbor.
- **Private VPC Route:** K3s Server và Worker tự động ánh xạ `hub.<HARBOR_EIP>.nip.io` về Private IP nội bộ của Harbor (`10.0.2.x`) trong `/etc/hosts` để kéo image siêu tốc qua mạng nội bộ.

---

## 2. Chiến Lược Chứng Chỉ TLS & Root CA Trust

> [!IMPORTANT]
> **Tuân thủ DevSecOps:** Tuyệt đối không sử dụng cờ `--insecure-registry` hoặc cờ `-k / --insecure` để bỏ qua kiểm tra chứng chỉ. Mọi giao tiếp registry bắt buộc phải xác thực TLS hợp lệ qua Root CA.

1. **Sinh Private Root CA:**
   - Tạo CA nội bộ tại `/data/cert/ca.key` và `/data/cert/ca.crt` (Thời hạn 365 ngày).
2. **Khai báo Subject Alternative Names (SAN) hợp lệ:**
   - `DNS.1 = hub.<HARBOR_EIP>.nip.io`
   - `DNS.2 = localhost`
   - `IP.1 = <HARBOR_PRIVATE_IP>`
   - `IP.2 = <HARBOR_EIP>`
   - `IP.3 = 127.0.0.1`
3. **Phân phối Root CA:**
   - Root CA (`ca.crt`) được Ansible tự động fetch về máy điều khiển và phân phối vào:
     + Hệ thống CA trust của máy chủ Harbor (`/usr/local/share/ca-certificates/harbor-ca.crt`).
     + `/etc/rancher/k3s/registries.yaml` trên cả K3s Server và Worker node.
4. **Bảo mật Credentials:**
   - Mật khẩu admin và mật khẩu database được quản lý tách biệt qua biến môi trường hoặc Ansible Vault (`harbor_admin_password`, `harbor_db_password`), nghiêm cấm dùng chung hoặc hardcode trong Git.
   - File cấu hình `harbor.yml` được đặt phân quyền bảo mật nghiêm ngặt `mode: 0600` với cờ `no_log: true`.

---

## 3. Các Lệnh Kiểm Chứng Harbor Registry

1. **Kiểm tra trạng thái Service & Containers:**
   ```bash
   docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
   # Kỳ vọng: harbor-core, harbor-db, harbor-portal, registry, trivy đều Up (healthy)
   ```
2. **Kiểm tra Health API qua HTTPS với CA Trust (Bật xác thực TLS):**
   ```bash
   curl --cacert /data/cert/ca.crt https://hub.<HARBOR_EIP>.nip.io/api/v2.0/ping
   # Kỳ vọng: HTTP/1.1 200 OK với phản hồi "pong"
   ```
3. **Thử nghiệm Đăng nhập và Push Image bằng Docker CLI (Khớp TV2 Workload):**
   ```bash
   # Sử dụng biến môi trường cho credentials
   echo "$HARBOR_PASSWORD" | docker login hub.<HARBOR_EIP>.nip.io -u <ROBOT_OR_ADMIN_USER> --password-stdin
   docker tag song-management:$SOURCE_SHA hub.<HARBOR_EIP>.nip.io/<project>/song-management:$SOURCE_SHA
   docker push hub.<HARBOR_EIP>.nip.io/<project>/song-management:$SOURCE_SHA
   docker buildx imagetools inspect hub.<HARBOR_EIP>.nip.io/<project>/song-management:$SOURCE_SHA
   ```
