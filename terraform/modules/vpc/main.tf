# modules/vpc/main.tf
# VPC: 10.0.0.0/16
# 2 Public Subnets + 2 Private DB Subnets + IGW + Route Tables

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ── VPC ───────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "${local.name_prefix}-vpc" }
}

# ── Public Subnets ────────────────────────────────────────────
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = ["10.0.1.0/24", "10.0.2.0/24"][count.index]
  availability_zone       = "${var.aws_region}${["a", "b"][count.index]}"
  map_public_ip_on_launch = true # K3s Worker cần Public IP cho egress
  tags = {
    Name = "${local.name_prefix}-public-subnet-${count.index + 1}"
    Tier = "Public"
  }
}

# ── Private DB Subnets ────────────────────────────────────────
resource "aws_subnet" "private_db" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = ["10.0.100.0/24", "10.0.200.0/24"][count.index]
  availability_zone       = "${var.aws_region}${["a", "b"][count.index]}"
  map_public_ip_on_launch = false # Private – không có Public IP
  tags = {
    Name = "${local.name_prefix}-private-db-subnet-${count.index + 1}"
    Tier = "PrivateDB"
  }
}

# ── Internet Gateway ──────────────────────────────────────────
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name_prefix}-igw" }
}

# ── Public Route Table (trỏ 0.0.0.0/0 ra IGW) ────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${local.name_prefix}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── Private Route Table (không có default route ra Internet) ──
resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.main.id
  # Không có route 0.0.0.0/0 → Isolated hoàn toàn
  tags = { Name = "${local.name_prefix}-private-db-rt" }
}

resource "aws_route_table_association" "private_db" {
  count          = 2
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db.id
}
