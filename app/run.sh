#!/usr/bin/env bash
###############################################################################
# run.sh — application entrypoint launched inside the tmux session by systemd.
#
# Replace the body with your real custom nameserver + reverse proxy launch
# command. This placeholder just proves the pipeline end-to-end: it keeps the
# tmux session alive and prints a heartbeat you can see with `tmux a`.
#
# Binding to ports 53 (DNS) and 443 (HTTPS) requires privilege. Options:
#   - run this service as root (change User= in the systemd unit), or
#   - keep the non-root user and grant your binary CAP_NET_BIND_SERVICE:
#       sudo setcap 'cap_net_bind_service=+ep' /opt/nameserver-proxy/<binary>
#     (deploy.sh does this automatically for ELF binaries named run.sh)
###############################################################################
set -euo pipefail

echo "[$(date -Is)] nameserver-proxy starting (pid $$)"

# --- EXAMPLE: put your real launch command here ------------------------------
# exec /opt/nameserver-proxy/mynameserver --config /opt/nameserver-proxy/config.yaml
# exec /opt/nameserver-proxy/reverse-proxy --listen :443
# -----------------------------------------------------------------------------

# Placeholder heartbeat loop so the tmux session stays attachable.
while true; do
  echo "[$(date -Is)] heartbeat — replace run.sh with your application"
  sleep 30
done
