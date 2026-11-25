# modules/ec2-k3s/variables.tf
variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for K3s instances (Public Subnet 1)"
  type        = string
}

variable "sg_server_id" {
  description = "Security Group ID for K3s Server"
  type        = string
}

variable "sg_worker_id" {
  description = "Security Group ID for K3s Worker"
  type        = string
}

variable "key_pair_name" {
  description = "SSH Key pair name"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile name (LabInstanceProfile on AWS Academy)"
  type        = string
  default     = "LabInstanceProfile"
}

variable "server_instance_type" {
  description = "EC2 instance type for K3s Server (Control Plane)"
  type        = string
  default     = "t3.medium"
}

variable "worker_instance_type" {
  description = "EC2 instance type for K3s Worker"
  type        = string
  default     = "t3.large"
}
