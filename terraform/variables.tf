###############################################################################
# Input variables
###############################################################################

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used to tag and name all resources."
  type        = string
  default     = "nameserver-proxy"
}

variable "allowed_account_ids" {
  description = <<-EOT
    Safety guard: AWS account IDs Terraform is permitted to deploy into. If the
    credentials at runtime resolve to any other account, Terraform aborts before
    creating anything. Set to the "Summer_fun" account (647379406056). Leave as
    an empty list to disable the check.
  EOT
  type        = list(string)
  default     = ["647379406056"]
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod). Used in tags/names."
  type        = string
  default     = "prod"
}

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet the EC2 instance lives in."
  type        = string
  default     = "10.20.1.0/24"
}

variable "availability_zone" {
  description = "AZ for the public subnet. Leave empty to auto-select the first AZ in the region."
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Compute
# -----------------------------------------------------------------------------
variable "instance_type" {
  description = "EC2 instance type. t3.micro (1GB/2vCPU) meets the minimum; use t3.small for more headroom."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "instance_type must be one of t3.micro, t3.small, or t3.medium."
  }
}

variable "root_volume_size_gb" {
  description = "Size of the root EBS volume in GiB."
  type        = number
  default     = 20
}

# -----------------------------------------------------------------------------
# SSH / access
# -----------------------------------------------------------------------------
variable "ssh_user" {
  description = "Non-root sudo user created on the host for SSH access (Debian's default cloud user is 'admin')."
  type        = string
  default     = "admin"
}

variable "ssh_port" {
  description = "TCP port sshd listens on. Change from 22 to reduce noise, but remember to update deploy scripts."
  type        = number
  default     = 22
}

variable "ssh_public_key" {
  description = "OpenSSH-format public key placed in the sudo user's authorized_keys for passwordless login."
  type        = string
  # No default: supply via terraform.tfvars or TF_VAR_ssh_public_key in CI/CD.
}

variable "ssh_ingress_cidrs" {
  description = <<-EOT
    CIDR blocks allowed to reach the SSH port. Defaults to the whole internet so
    first-time setup works, but you SHOULD restrict this to your office / VPN /
    CI runner egress IP(s), e.g. ["203.0.113.4/32"].
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "http_ingress_cidrs" {
  description = "CIDR blocks allowed to reach TCP 80 (HTTP; also needed for Let's Encrypt HTTP-01 challenges)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "https_ingress_cidrs" {
  description = "CIDR blocks allowed to reach TCP 443 (web traffic)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "dns_ingress_cidrs" {
  description = "CIDR blocks allowed to reach UDP 53 (inbound DNS / nameserver traffic)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_dns_tcp" {
  description = <<-EOT
    Also open TCP 53. DNS uses TCP for responses larger than the UDP limit
    (zone transfers, DNSSEC, EDNS fallback). The task only requires UDP 53, so
    this defaults to false, but most real nameservers want it true.
  EOT
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}
