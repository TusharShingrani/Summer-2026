###############################################################################
# Provider + shared data sources / locals
###############################################################################

provider "aws" {
  region = var.aws_region

  # Refuse to run unless the resolved credentials belong to one of these
  # accounts (the "Summer_fun" account). Prevents deploying to the wrong place.
  allowed_account_ids = var.allowed_account_ids

  default_tags {
    tags = merge(
      {
        Project     = var.project_name
        Environment = var.environment
        ManagedBy   = "terraform"
      },
      var.tags,
    )
  }
}

# Who am I? Confirms which account/identity the credentials resolved to.
data "aws_caller_identity" "current" {}

# Available AZs in the region (used when availability_zone is left empty).
data "aws_availability_zones" "available" {
  state = "available"
}

# Latest official Debian 12 (Bookworm) AMI for x86_64.
# 136693071363 is the Debian project's AWS account.
data "aws_ami" "debian12" {
  most_recent = true
  owners      = ["136693071363"]

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

locals {
  name = "${var.project_name}-${var.environment}"

  availability_zone = coalesce(
    var.availability_zone,
    data.aws_availability_zones.available.names[0],
  )
}
