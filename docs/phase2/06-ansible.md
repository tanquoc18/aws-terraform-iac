# P2-06 — BÁO CÁO CẤU HÌNH ANSIBLE VÀ ĐƯỜNG QUẢN TRỊ BASTION / SSM

> **Dự án:** Tự động hóa triển khai ứng dụng 2-Tier theo DevSecOps/GitOps trên AWS  
> **Thực hiện:** Thành viên 1 (Cloud Infrastructure & Platform Engineer)  
> **Ngày lập:** 22/11/2026  
> **Tài liệu tham chiếu:** `PHASE2.md` v1.0, Work Package P2-06  
> **Trạng thái:** `READY_FOR_EXECUTION`  

---

## 1. Cơ Chế Sinh Inventory Tự Động Từ Terraform Outputs

File script `ansible/inventory/generate_inventory.py` tự động đọc `terraform output -json` từ thư mục `terraform/` và sinh ra `ansible/inventory/hosts.ini` với đầy đủ các thuộc tính thật:

```ini
[harbor]
harbor_server ansible_host=<HARBOR_EIP> harbor_private_ip=10.0.2.x ansible_user=ubuntu

[k3s_server]
k3s_master ansible_host=<SERVER_EIP> server_private_ip=10.0.1.x ansible_user=ubuntu

[k3s_worker]
# Worker CHẶN 100% Inbound Internet. Quản trị nghiêm ngặt qua SSH ProxyJump qua Server Bastion
k3s_node1 ansible_host=10.0.1.y worker_private_ip=10.0.1.y ansible_user=ubuntu ansible_ssh_common_args='-o ProxyJump=ubuntu@<SERVER_EIP>'
```

* **Zero Placeholder IPs:** Không tồn tại bất kỳ IP tĩnh hay giả lập nào.
* **Bảo vệ Worker:** Worker không mở cổng SSH ra Internet, mọi kết nối Ansible đều nhảy cầu (Jump) qua máy chủ K3s Server Bastion.
* **Cấu hình `ansible.cfg`:** Giữ nguyên `host_key_checking = True` (hoặc `StrictHostKeyChecking=accept-new` an toàn) để ngăn chặn tấn công Man-In-The-Middle.

---

## 2. Hoàn Thiện Các Roles Thực Tế (Không Dùng Debug Giả)

1. **Role `common`:**
   - Tắt Swap hoàn toàn (`swapoff -a` có guard kiểm tra và comment fstab).
   - Nạp kernel modules `overlay`, `br_netfilter` cho CNI Flannel.
   - Kích hoạt sysctl `net.ipv4.ip_forward = 1` và `bridge-nf-call-iptables = 1`.
   - Cài đặt đầy đủ gói cơ sở: `curl`, `wget`, `htop`, `jq`, `ca-certificates`.
2. **Role `docker`:**
   - Cài đặt Docker CE Engine, containerd.io và Docker Compose plugin chính thức từ kho Docker Ubuntu Jammy.
   - Thiết lập `/etc/docker/daemon.json` với log driver `json-file` giới hạn `max-size: 50m`, `max-file: 3` chống tràn ổ cứng EBS.
   - Kích hoạt service Docker khởi động cùng OS.

---

## 3. Quy Trình Kiểm Thử Cú Pháp & Hội Tụ (Idempotency)

```bash
# 1. Kiểm tra cú pháp (Syntax Check)
ansible-playbook -i inventory/hosts.ini playbooks/01-site.yml --syntax-check

# 2. Chạy thử nghiệm mô phỏng (Dry-run)
ansible-playbook -i inventory/hosts.ini playbooks/01-site.yml --check --diff

# 3. Chạy thực tế Lần 1 (Setup toàn diện)
ansible-playbook -i inventory/hosts.ini playbooks/01-site.yml

# 4. Chạy kiểm chứng Hội tụ Lần 2 (Idempotency Proof)
ansible-playbook -i inventory/hosts.ini playbooks/01-site.yml
# Kỳ vọng: Toàn bộ tasks đều trả về 'ok', changed=0, failed=0
```
