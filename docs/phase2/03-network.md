# P2-03 — BÁO CÁO THIẾT KẾ MẠNG VÀ MA TRẬN SECURITY GROUP CHAINING

> **Dự án:** Tự động hóa triển khai ứng dụng 2-Tier theo DevSecOps/GitOps trên AWS  
> **Thực hiện:** Thành viên 1 (Cloud Infrastructure & Platform Engineer)  
> **Ngày lập:** 22/11/2026  
> **Tài liệu tham chiếu:** `PHASE2.md` v1.0, Work Package P2-03  
> **Trạng thái kiểm định Offline:** `PASS` (Validate đạt, toàn bộ description chuẩn ASCII)  

---

## 1. Thiết Kế Kiến Trúc Mạng VPC (`10.0.0.0/16`)

Hệ thống mạng được phân tách thành 2 vùng rõ rệt (Public Tier và Private DB Tier) trải rộng trên 2 Availability Zones (`us-east-1a` và `us-east-1b`) đã được xác minh thực tế ở Gate 0:

| Phân vùng Subnet | CIDR Block | Availability Zone | Tier | Route Table & Cổng mạng |
|---|---|---|---|---|
| **Public Subnet 1** | `10.0.1.0/24` | `us-east-1a` | Public | Route `0.0.0.0/0` -> Internet Gateway (K3s Server, K3s Worker) |
| **Public Subnet 2** | `10.0.2.0/24` | `us-east-1b` | Public | Route `0.0.0.0/0` -> Internet Gateway (Harbor Registry) |
| **Private DB Subnet 1** | `10.0.100.0/24` | `us-east-1a` | PrivateDB | Không có route ra Internet (RDS Instance Subnet AZ 1) |
| **Private DB Subnet 2** | `10.0.200.0/24` | `us-east-1b` | PrivateDB | Không có route ra Internet (RDS Instance Subnet AZ 2) |

> [!NOTE]
> Thiết kế **KHÔNG sử dụng NAT Gateway** (tiết kiệm chi phí ~$32/tháng và tránh lỗi quota Lab). Worker Node nằm ở Public Subnet 1 có Public IP chỉ phục vụ cho chiều **Egress ra ngoài** (tải packages/ảnh), trong khi chiều Inbound bị Security Group chặn 100%.

---

## 2. Ma Trận Security Group Chaining Thực Tế (§2.2)

Toàn bộ rules được khai báo bằng tài nguyên độc lập `aws_vpc_security_group_ingress_rule` và `aws_vpc_security_group_egress_rule` với `referenced_security_group_id` tường minh, mô tả hoàn toàn bằng chuẩn ASCII:

```
[ Internet ] ──( HTTP 80 / HTTPS 443 )──> [ sg-k3s-server ]
[ Admin My IP ] ──( SSH 22 / API 6443 )─> [ sg-k3s-server ]
[ Admin My IP ] ──( SSH 22 )───────────> [ sg-harbor ]

[ sg-k3s-server ] ──( Overlay 8472 / Kubelet 10250 / SSH Jump 22 )──> [ sg-k3s-worker ]
[ sg-k3s-worker ] ──( Flannel 8472 / Kubelet 10250 / Agent 6443 )───> [ sg-k3s-server ]

[ sg-k3s-worker ] ──( PostgreSQL TCP 5432 DUY NHẤT )───────────────> [ sg-rds ]
(Mọi nguồn khác như Internet, Server, Harbor đều bị DROP tới RDS)

[ sg-k3s-worker / Server ] ──( Pull Image HTTPS 443 nội bộ )────────> [ sg-harbor ]
[ sg-k3s-worker (Prometheus) ] ──( Scrape Metrics TCP 9100 )────────> [ sg-harbor ]
```

### Chi Tiết Cấu Hình Các Nhóm Bảo Mật:

### 2.1. `sg-k3s-server` (`${project_name}-k3s-server`)
- Inbound:
  + `80/tcp`, `443/tcp`: `0.0.0.0/0` (Public HTTP/HTTPS tới Traefik Ingress Controller).
  + `6443/tcp`: `var.my_ip_cidr` (K3s API admin access từ IP bảo mật của bạn).
  + `6443/tcp`: từ `sg-k3s-worker` (Worker Agent đăng ký cluster).
  + `8472/udp`: từ `sg-k3s-worker` (Flannel VXLAN overlay network).
  + `10250/tcp`: từ `sg-k3s-worker` (Kubelet metrics).
  + `22/tcp`: `var.my_ip_cidr` (SSH admin access).
- Egress: `0.0.0.0/0` All traffic.

### 2.2. `sg-k3s-worker` (`${project_name}-k3s-worker`)
- Inbound: **TUYỆT ĐỐI KHÔNG CÓ RULE 0.0.0.0/0 (CHẶN 100% INTERNET)**.
  + `8472/udp`: từ `sg-k3s-server` (Flannel overlay).
  + `10250/tcp`: từ `sg-k3s-server` (Kubelet API cho logs/exec).
  + `22/tcp`: từ `sg-k3s-server` (Chỉ cho phép SSH jump nội bộ từ Server Bastion).
  + `9100/tcp`: từ chính `sg-k3s-worker` (Prometheus cào Node Exporter cục bộ).
  + *Đã loại bỏ:* Toàn bộ dải NodePort `30000-32767` theo đúng yêu cầu bảo mật.
- Egress: `0.0.0.0/0` All traffic (cho phép kéo packages OS và images).

### 2.3. `sg-rds` (`${project_name}-rds`)
- Inbound: **CHỈ DUY NHẤT 1 RULE**:
  + `5432/tcp`: từ `sg-k3s-worker` (FastAPI Pods & Alembic Migration Job).
  + Internet, K3s Server, Harbor đều bị DROP kết nối.
- Egress: **ZERO RULES** (Database không có bất kỳ kết nối khởi tạo ra ngoài).

### 2.4. `sg-harbor` (`${project_name}-harbor`)
- Inbound:
  + `80/tcp`, `443/tcp`: `0.0.0.0/0` (Harbor Web UI & HTTPS registry).
  + `443/tcp`: từ `sg-k3s-worker` và `sg-k3s-server` (Kéo image nội bộ VPC).
  + `22/tcp`: `var.my_ip_cidr` (SSH admin access).
  + `9100/tcp`: từ `sg-k3s-worker` (Prometheus cào Node Exporter).
- Egress: `0.0.0.0/0` All traffic.

---

## 3. Rà Soát Tính Hợp Lệ Của Inputs
- Đã thêm `validation` cho biến `project_name`: chỉ chấp nhận ký tự thường `a-z`, `0-9` và `-`.
- Đã thêm `validation` cho biến `my_ip_cidr`: bắt buộc kiểm tra định dạng chuẩn IPv4 CIDR qua hàm `cidrnetmask` và `cidrhost`.
