###############################################################################
# Compute: SSH key pair, EC2 instance, and a fixed public IP (Elastic IP)
###############################################################################

# Register the operator's public key with EC2 so it is injected at first boot.
# The cloud-init user-data also writes it to the sudo user's authorized_keys,
# so passwordless SSH works regardless of which mechanism you rely on.
resource "aws_key_pair" "server" {
  key_name   = "${local.name}-key"
  public_key = var.ssh_public_key

  tags = {
    Name = "${local.name}-key"
  }
}

# Cloud-init user-data: prepares the host (sudo user, SSH hardening,
# frees ports 53/443, installs tmux, wires up the systemd/tmux service).
locals {
  user_data = templatefile("${path.module}/../cloud-init/user-data.sh.tftpl", {
    ssh_user       = var.ssh_user
    ssh_port       = var.ssh_port
    ssh_public_key = var.ssh_public_key
    project_name   = var.project_name
  })
}

resource "aws_instance" "server" {
  ami                    = data.aws_ami.debian12.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.server.id]
  key_name               = aws_key_pair.server.key_name
  user_data              = local.user_data

  # Re-run user-data if the rendered content changes.
  user_data_replace_on_change = true

  metadata_options {
    http_tokens   = "required" # enforce IMDSv2
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_size           = var.root_volume_size_gb
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = local.name
    Role = "nameserver-reverse-proxy"
  }
}

# Elastic IP: a fixed, static public IP that survives stop/start and instance
# replacement. This is the address you will later point your GoDaddy domain's
# glue / A / NS records at.
resource "aws_eip" "server" {
  domain = "vpc"

  tags = {
    Name = "${local.name}-eip"
  }

  # Ensure the IGW exists before allocating/associating the EIP.
  depends_on = [aws_internet_gateway.main]
}

resource "aws_eip_association" "server" {
  instance_id   = aws_instance.server.id
  allocation_id = aws_eip.server.id
}
