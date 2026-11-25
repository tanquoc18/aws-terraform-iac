# modules/ec2-harbor/main.tf
# EC2 Harbor Registry: t3.medium + 60GB EBS gp3 data volume + Elastic IP

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

resource "aws_instance" "harbor" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_pair_name
  iam_instance_profile   = var.iam_instance_profile

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    tags = {
      Name    = "${var.project_name}-harbor-root"
      Project = var.project_name
    }
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e
              # Prepare /data mount point for dedicated 60GB EBS
              mkdir -p /data
              EOF

  tags = {
    Name    = "${var.project_name}-harbor"
    Role    = "Harbor-Registry"
    Project = var.project_name
  }
}

# Dedicated 60GB EBS gp3 volume for Harbor image storage
resource "aws_ebs_volume" "harbor_data" {
  availability_zone = aws_instance.harbor.availability_zone
  size              = 60
  type              = "gp3"
  tags = {
    Name    = "${var.project_name}-harbor-data-60gb"
    Project = var.project_name
  }
}

resource "aws_volume_attachment" "harbor_data" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.harbor_data.id
  instance_id = aws_instance.harbor.id
}

# Elastic IP allocation and association
resource "aws_eip" "harbor" {
  domain = "vpc"
  tags = {
    Name    = "${var.project_name}-harbor-eip"
    Project = var.project_name
  }
}

resource "aws_eip_association" "harbor" {
  instance_id   = aws_instance.harbor.id
  allocation_id = aws_eip.harbor.id
}
