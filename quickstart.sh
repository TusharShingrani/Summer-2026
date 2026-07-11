#!/usr/bin/env bash
###############################################################################
# quickstart.sh — the shortest path from zero to a running VPS.
#
# Run this ON YOUR OWN MACHINE (laptop / any box with the AWS CLI). It:
#   1. checks you have AWS credentials and prints which account they're for,
#   2. makes an SSH key if you don't have one,
#   3. runs Terraform to create the VPC, EC2 (Debian 12) and Elastic IP,
#   4. prints the fixed IP and the exact `ssh` command to get in.
#
# Usage:
#   ./quickstart.sh
#
# Prereqs (one-time, on your machine):
#   - AWS CLI     : https://aws.amazon.com/cli/    then `aws configure`  (or SSO)
#   - Terraform   : https://developer.hashicorp.com/terraform/downloads
# Your AWS creds must be for the Summer_fun account (647379406056).
###############################################################################
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$REPO_ROOT/terraform"
EXPECT_ACCOUNT="647379406056"
KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/nameserver-proxy}"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
red()  { printf '\033[31m%s\033[0m\n' "$*"; }
grn()  { printf '\033[32m%s\033[0m\n' "$*"; }

# --- 0. tools present? ------------------------------------------------------
for tool in aws terraform ssh-keygen; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    red "Missing required tool: $tool"
    case "$tool" in
      aws)       echo "  Install: https://aws.amazon.com/cli/  then run: aws configure" ;;
      terraform) echo "  Install: https://developer.hashicorp.com/terraform/downloads" ;;
    esac
    exit 1
  fi
done

# --- 1. AWS credentials + account check -------------------------------------
bold ">> Checking AWS credentials..."
if ! ACCOUNT="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)"; then
  red "No working AWS credentials found."
  echo "  Set them up first, e.g.:"
  echo "    aws configure                 # paste an access key for account $EXPECT_ACCOUNT"
  echo "    # or, if you use SSO:"
  echo "    aws sso login --profile summer_fun && export AWS_PROFILE=summer_fun"
  exit 1
fi

if [ "$ACCOUNT" = "$EXPECT_ACCOUNT" ]; then
  grn "   Authenticated to account $ACCOUNT (Summer_fun) ✔"
else
  red "   WARNING: your credentials are for account $ACCOUNT, not $EXPECT_ACCOUNT (Summer_fun)."
  echo "   Terraform will refuse to run against the wrong account (this is the built-in guardrail)."
  read -r -p "   Continue anyway? [y/N] " ans
  [ "${ans:-N}" = "y" ] || [ "${ans:-N}" = "Y" ] || { echo "Aborting."; exit 1; }
fi

# --- 2. SSH key -------------------------------------------------------------
if [ ! -f "$KEY_PATH" ]; then
  bold ">> No SSH key at $KEY_PATH — generating one..."
  ssh-keygen -t ed25519 -N "" -f "$KEY_PATH" -C "nameserver-proxy"
  grn "   Created $KEY_PATH and $KEY_PATH.pub"
else
  echo ">> Using existing SSH key: $KEY_PATH"
fi
export TF_VAR_ssh_public_key="$(cat "$KEY_PATH.pub")"

# --- 3. Terraform -----------------------------------------------------------
cd "$TF_DIR"
bold ">> terraform init"
terraform init -input=false

bold ">> terraform apply  (review the plan, then type 'yes' to build it)"
if [ "${AUTO_APPROVE:-0}" = "1" ]; then
  terraform apply -input=false -auto-approve
else
  terraform apply -input=false
fi

# --- 4. Done — how to get in ------------------------------------------------
IP="$(terraform output -raw elastic_ip)"
USER_="$(terraform output -raw ssh_user)"
PORT="$(terraform output -raw ssh_port)"

echo
grn "============================================================"
grn " VPS is up.  Fixed public IP: $IP"
grn "============================================================"
echo
echo " SSH in with:"
echo "   ssh -i $KEY_PATH -p $PORT $USER_@$IP"
echo
echo " Give it ~60-90s after creation for first-boot setup to finish."
echo " Then deploy your app with:"
echo "   SSH_KEY_FILE=$KEY_PATH SSH_USER=$USER_ SSH_PORT=$PORT $REPO_ROOT/scripts/deploy.sh $IP"
echo
echo " Tear it all down later with:  cd terraform && terraform destroy"
