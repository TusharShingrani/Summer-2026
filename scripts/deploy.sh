#!/usr/bin/env bash
###############################################################################
# deploy.sh — ship the application to the remote AWS host over scp + ssh.
#
# Usage:
#   SSH_KEY_FILE=~/keys/ssh.key SSH_USER=admin ./scripts/deploy.sh <server_ip>
#
# Environment variables:
#   SSH_KEY_FILE  Path to the PRIVATE key for auth        (default: ~/.ssh/id_ed25519)
#   SSH_USER      Remote sudo user                        (default: admin)
#   SSH_PORT      Remote sshd port                        (default: 22)
#   APP_DIR       Local dir whose contents get shipped    (default: ./app)
#   REMOTE_DIR    Remote install path                     (default: /opt/nameserver-proxy)
#   SERVICE_NAME  systemd unit to restart after upload    (default: nameserver-proxy)
#
# Example (matches the task's requested form):
#   SSH_KEY_FILE=~/keys/ssh.key SSH_USER=admin SSH_PORT=22 ./scripts/deploy.sh 203.0.113.10
###############################################################################
set -euo pipefail

SERVER_IP="${1:-}"
if [[ -z "$SERVER_IP" ]]; then
  echo "usage: SSH_KEY_FILE=... SSH_USER=... $0 <server_ip>" >&2
  exit 2
fi

SSH_KEY_FILE="${SSH_KEY_FILE:-$HOME/.ssh/id_ed25519}"
SSH_USER="${SSH_USER:-admin}"
SSH_PORT="${SSH_PORT:-22}"
APP_DIR="${APP_DIR:-./app}"
REMOTE_DIR="${REMOTE_DIR:-/opt/nameserver-proxy}"
SERVICE_NAME="${SERVICE_NAME:-nameserver-proxy}"

if [[ ! -f "$SSH_KEY_FILE" ]]; then
  echo "error: SSH_KEY_FILE '$SSH_KEY_FILE' not found" >&2
  exit 1
fi
chmod 600 "$SSH_KEY_FILE" 2>/dev/null || true

# Common ssh/scp options: use our key & port, fail fast, don't prompt on first
# connect (StrictHostKeyChecking=accept-new records the key but won't hang CI).
SSH_OPTS=(
  -i "$SSH_KEY_FILE"
  -p "$SSH_PORT"
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=15
  -o BatchMode=yes
)
# scp takes the port as -P (capital), everything else is shared.
SCP_OPTS=(
  -i "$SSH_KEY_FILE"
  -P "$SSH_PORT"
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=15
  -o BatchMode=yes
  -r
)

REMOTE="${SSH_USER}@${SERVER_IP}"

echo ">> Deploying '$APP_DIR' to ${REMOTE}:${REMOTE_DIR} (port ${SSH_PORT})"

# 1. Sanity check connectivity.
ssh "${SSH_OPTS[@]}" "$REMOTE" 'echo "connected to $(hostname) as $(whoami)"'

# 2. Upload the application to a staging dir, then move into place with sudo.
STAGING="/tmp/${SERVICE_NAME}-deploy.$$"
ssh "${SSH_OPTS[@]}" "$REMOTE" "rm -rf '$STAGING' && mkdir -p '$STAGING'"
scp "${SCP_OPTS[@]}" "$APP_DIR"/. "${REMOTE}:${STAGING}/"

# 3. Install into REMOTE_DIR, fix perms, allow binding to low ports, restart.
ssh "${SSH_OPTS[@]}" "$REMOTE" "sudo bash -s" <<REMOTE_SCRIPT
set -euxo pipefail
sudo install -d -m 0755 "$REMOTE_DIR"
sudo cp -a "$STAGING"/. "$REMOTE_DIR"/
sudo chown -R "$SSH_USER":"$SSH_USER" "$REMOTE_DIR"
sudo chmod +x "$REMOTE_DIR"/run.sh || true

# If the app is a binary that must bind 53/443 as a non-root user, grant the
# capability instead of running as root (edit APP_BIN to match your binary).
APP_BIN="$REMOTE_DIR/run.sh"
if file "\$APP_BIN" 2>/dev/null | grep -q ELF; then
  sudo setcap 'cap_net_bind_service=+ep' "\$APP_BIN" || true
fi

rm -rf "$STAGING"
sudo systemctl restart "$SERVICE_NAME"
sudo systemctl --no-pager status "$SERVICE_NAME" | head -n 15
REMOTE_SCRIPT

echo ">> Deploy complete. Service '${SERVICE_NAME}' restarted on ${SERVER_IP}."
