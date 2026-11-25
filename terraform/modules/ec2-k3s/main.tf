# modules/ec2-k3s/main.tf
# K3s Cluster EC2 Instances: 1 Server (t3.medium) + 1 Worker (t3.large)

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── K3s Control Plane Server ──────────────────────────────────
resource "aws_instance" "k3s_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.server_instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.sg_server_id]
  key_name               = var.key_pair_name
  iam_instance_profile   = var.iam_instance_profile

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    tags = {
      Name    = "${var.project_name}-k3s-server-root"
      Project = var.project_name
    }
  }

  tags = {
    Name    = "${var.project_name}-k3s-server"
    Role    = "K3s-Server-ControlPlane"
    Project = var.project_name
  }
}

# Elastic IP allocation and association for K3s Server
resource "aws_eip" "k3s_server" {
  domain = "vpc"
  tags = {
    Name    = "${var.project_name}-k3s-server-eip"
    Project = var.project_name
  }
}

resource "aws_eip_association" "k3s_server" {
  instance_id   = aws_instance.k3s_server.id
  allocation_id = aws_eip.k3s_server.id
}

# ── K3s Worker Node ───────────────────────────────────────────
resource "aws_instance" "k3s_worker" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.worker_instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.sg_worker_id]
  key_name                    = var.key_pair_name
  iam_instance_profile        = var.iam_instance_profile
  associate_public_ip_address = true # Public IP strictly for outbound egress

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
    tags = {
      Name    = "${var.project_name}-k3s-worker-root"
      Project = var.project_name
    }
  }

  tags = {
    Name    = "${var.project_name}-k3s-worker"
    Role    = "K3s-Worker-Compute"
    Project = var.project_name
  }
}
