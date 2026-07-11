###############################################################################
# Outputs
###############################################################################

output "elastic_ip" {
  description = "Fixed public IP of the server. Point your GoDaddy DNS records here later."
  value       = aws_eip.server.public_ip
}

output "aws_account_id" {
  description = "Account the credentials resolved to. Should be 647379406056 (Summer_fun)."
  value       = data.aws_caller_identity.current.account_id
}

output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.server.id
}

output "ami_id" {
  description = "Debian 12 AMI the instance was launched from."
  value       = data.aws_ami.debian12.id
}

output "ssh_user" {
  description = "Sudo user for SSH."
  value       = var.ssh_user
}

output "ssh_port" {
  description = "Port sshd listens on."
  value       = var.ssh_port
}

output "ssh_command" {
  description = "Ready-to-use SSH command (assumes your private key is the default identity)."
  value       = "ssh -p ${var.ssh_port} ${var.ssh_user}@${aws_eip.server.public_ip}"
}

output "deploy_command" {
  description = "Example invocation of scripts/deploy.sh against this host."
  value       = "SSH_KEY_FILE=~/keys/ssh.key SSH_USER=${var.ssh_user} SSH_PORT=${var.ssh_port} ./scripts/deploy.sh ${aws_eip.server.public_ip}"
}

# Placeholders that become useful once you attach the GoDaddy domain.
output "nameserver_hint" {
  description = "When you register glue records at GoDaddy, map your ns hostnames to this IP."
  value       = "ns1.<your-domain>  ->  ${aws_eip.server.public_ip}"
}
