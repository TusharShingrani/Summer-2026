###############################################################################
# Security Group: inbound firewall for the nameserver / reverse-proxy host
#
# Required inbound rules (from the task):
#   - TCP 22  (SSH)   remote configuration
#   - TCP 443 (HTTPS) reverse-proxy web traffic
#   - UDP 53  (DNS)   inbound nameserver traffic / hostname resolution
#
# Optional:
#   - TCP 53  (DNS over TCP) enabled via var.enable_dns_tcp
#
# Egress is fully open so the host can install packages, fetch upstream DNS
# answers, and proxy to backends.
###############################################################################

resource "aws_security_group" "server" {
  name        = "${local.name}-sg"
  description = "Inbound rules for the custom nameserver + reverse proxy"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name}-sg"
  }
}

# --- SSH (TCP 22, or var.ssh_port) ------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.server.id
  description       = "SSH for remote configuration"

  for_each    = toset(var.ssh_ingress_cidrs)
  cidr_ipv4   = each.value
  ip_protocol = "tcp"
  from_port   = var.ssh_port
  to_port     = var.ssh_port
}

# --- HTTPS (TCP 443) --------------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.server.id
  description       = "HTTPS reverse-proxy web traffic"

  for_each    = toset(var.https_ingress_cidrs)
  cidr_ipv4   = each.value
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}

# --- DNS over UDP (UDP 53) --------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "dns_udp" {
  security_group_id = aws_security_group.server.id
  description       = "Inbound DNS (UDP) for the custom nameserver"

  for_each    = toset(var.dns_ingress_cidrs)
  cidr_ipv4   = each.value
  ip_protocol = "udp"
  from_port   = 53
  to_port     = 53
}

# --- DNS over TCP (TCP 53) -- optional --------------------------------------
resource "aws_vpc_security_group_ingress_rule" "dns_tcp" {
  for_each = var.enable_dns_tcp ? toset(var.dns_ingress_cidrs) : toset([])

  security_group_id = aws_security_group.server.id
  description       = "Inbound DNS (TCP) for large responses / zone transfers"

  cidr_ipv4   = each.value
  ip_protocol = "tcp"
  from_port   = 53
  to_port     = 53
}

# --- Egress: allow all outbound --------------------------------------------
resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.server.id
  description       = "Allow all outbound traffic"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}
