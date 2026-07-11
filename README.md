# Custom Nameserver + Reverse Proxy on AWS EC2

Infrastructure-as-Code (Terraform) to deploy a secure Debian 12 EC2 host that
runs a **custom nameserver** and **reverse proxy**, with a **fixed public IP
(Elastic IP)**, proper internet routing, and a firewall opening SSH (22/tcp),
HTTPS (443/tcp) and DNS (53/udp). Deployable by hand or from a CI/CD pipeline.

> Domain note: this repo stands the server up and gives you a stable Elastic IP.
> Pointing your **GoDaddy** domain at it (glue records + NS/A records) is a
> later step — the IP won't change, so you can come back to it any time. See
> [Attaching your GoDaddy domain (later)](#attaching-your-godaddy-domain-later).

---

## 🚀 Just want the VPS running? (fastest path)

The server is created in **your** AWS account, so you need AWS credentials on
your machine — that's the one thing no script can do for you. Once you have
them, it's a single command:

```bash
# 1. One-time: point the AWS CLI at the Summer_fun account (647379406056)
aws configure                 # paste an access key/secret for that account
#    ...or with SSO:  aws sso login --profile summer_fun && export AWS_PROFILE=summer_fun

# 2. Build it (checks your account, makes an SSH key, runs Terraform):
./quickstart.sh
```

When it finishes it prints your **fixed IP** and the exact `ssh` command to log
in. Total time ≈ 2 minutes. Tear it down anytime with `cd terraform &&
terraform destroy`.

> No AWS access key yet? In the AWS Console: **IAM → Users → your user →
> Security credentials → Create access key → CLI**. Then `aws configure`.
>
> Prefer to deploy from GitHub Actions instead of your laptop? That works too
> but needs extra one-time IAM setup — see [CI/CD setup](#cicd-setup). For just
> getting a box up, `quickstart.sh` is the shortcut.

---

## What gets created

| Layer      | Resource                                                        |
|------------|-----------------------------------------------------------------|
| Network    | VPC, Internet Gateway, public subnet, route table (0.0.0.0/0 → IGW) |
| Firewall   | Security Group: **22/tcp**, **443/tcp**, **53/udp** (+ optional 53/tcp) |
| Compute    | Debian 12 EC2 instance (t3.micro/small, IMDSv2, encrypted gp3)   |
| Fixed IP   | **Elastic IP** associated with the instance                     |
| Host prep  | cloud-init: sudo user, SSH hardening, frees 53/443, tmux + systemd |

```
                internet
                   │
             ┌─────▼──────┐   Elastic IP (fixed)
             │    IGW      │
             └─────┬──────┘
        route 0.0.0.0/0 → IGW
             ┌─────▼──────────────┐
             │  public subnet      │
             │   ┌──────────────┐  │  SG inbound: 22/tcp, 443/tcp, 53/udp
             │   │  EC2 Debian12 │  │  app in tmux, started by systemd
             │   └──────────────┘  │
             └────────────────────┘
```

Repo layout:

```
terraform/            # the IaC (VPC, SG, EC2, EIP)
cloud-init/           # user-data that prepares the host on first boot
scripts/deploy.sh     # env-var-driven scp/ssh application deploy
app/run.sh            # sample application entrypoint (replace with yours)
systemd/              # reference copy of the tmux-launching unit
.github/workflows/    # CI/CD pipeline
```

---

## Prerequisites

- An AWS account + credentials with permission to manage VPC/EC2/EIP.
- [Terraform](https://developer.hashicorp.com/terraform/downloads) ≥ 1.5.
- An SSH key pair. Create one if needed:
  ```bash
  ssh-keygen -t ed25519 -f ~/keys/ssh.key -C "nameserver-proxy"
  # public key  -> ~/keys/ssh.key.pub  (goes into Terraform)
  # private key -> ~/keys/ssh.key       (stays on your machine / CI secret)
  ```

---

## Which AWS account does this deploy to?

Nothing in the code hardcodes an account. Terraform deploys to whatever account
the **credentials at runtime** belong to, resolved in this order:

1. `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (+ `AWS_SESSION_TOKEN`) env vars
2. A named profile (`AWS_PROFILE`, `~/.aws/credentials`)
3. In CI: the **OIDC role** the pipeline assumes (`AWS_ROLE_ARN`)
4. An EC2/ECS instance role, if Terraform itself runs on AWS

This project targets the **`Summer_fun`** account, **`647379406056`**. Two
things enforce that:

- `allowed_account_ids = ["647379406056"]` in the provider — Terraform **aborts
  before creating anything** if the resolved credentials belong to a different
  account.
- The `aws_account_id` output echoes the account so you can eyeball it.

Point your credentials at that account first. Examples:

```bash
# SSO (recommended):
aws sso login --profile summer_fun
export AWS_PROFILE=summer_fun

# ...or a specific profile / static keys for the 647379406056 account.
# Confirm you're in the right place BEFORE apply:
aws sts get-caller-identity --query Account --output text   # -> 647379406056
```

If you ever run with the wrong credentials, you'll see:
`Error: AWS account ID not allowed` — that's the guardrail doing its job.

---

## Step-by-step: from zero to listening ports

### Step 1 — Configure variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region     = "us-east-1"
instance_type  = "t3.micro"           # or t3.small
ssh_user       = "admin"
ssh_port       = 22
ssh_public_key = "ssh-ed25519 AAAA... you@example.com"   # contents of ssh.key.pub
# ssh_ingress_cidrs = ["203.0.113.4/32"]   # lock SSH to your IP once it works
# enable_dns_tcp    = true                 # recommended for a real nameserver
```

> **Why an Elastic IP?** A default EC2 public IP changes every stop/start. The
> Elastic IP in `ec2.tf` is static, so your DNS records (and clients) keep
> working across reboots and instance replacements.

### Step 2 — Launch the instance (equivalent of the AWS Console "Launch")

```bash
terraform init
terraform plan       # review
terraform apply      # type 'yes'
```

Terraform performs everything the Console launch wizard would:
- picks the latest official **Debian 12** AMI,
- creates the **VPC / subnet / IGW / route table** (internet + routing),
- attaches the **Security Group** with 22/443/53 open,
- launches the **t3.micro** instance and runs the **cloud-init** host prep,
- allocates and associates the **Elastic IP**.

Grab the outputs:

```bash
terraform output
# elastic_ip     = "203.0.113.10"
# ssh_command    = "ssh -p 22 admin@203.0.113.10"
# deploy_command = "SSH_KEY_FILE=~/keys/ssh.key SSH_USER=admin ... 203.0.113.10"
```

### Step 3 — Verify passwordless SSH as the sudo user

cloud-init already created the non-root **sudo** user and installed your public
key, so this just works (no password):

```bash
ssh -i ~/keys/ssh.key -p 22 admin@203.0.113.10
# on the host:
sudo whoami        # -> root   (confirms passwordless sudo)
```

<details>
<summary>What cloud-init did on the host (the manual equivalents)</summary>

**Create a non-root sudo user**
```bash
sudo useradd --create-home --shell /bin/bash admin
echo 'admin ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/90-admin
sudo chmod 0440 /etc/sudoers.d/90-admin
```

**Passwordless SSH — add your public key**
```bash
sudo install -d -m 700 -o admin -g admin /home/admin/.ssh
echo 'ssh-ed25519 AAAA... you@example.com' | sudo tee /home/admin/.ssh/authorized_keys
sudo chmod 600 /home/admin/.ssh/authorized_keys
sudo chown admin:admin /home/admin/.ssh/authorized_keys
```

**Harden sshd** (`/etc/ssh/sshd_config.d/10-hardening.conf`)
```
Port 22
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```
```bash
sudo systemctl restart ssh
```
</details>

### Step 4 — Confirm ports 53 & 443 are free (conflicting services disabled)

Debian 12 ships **systemd-resolved** bound to `127.0.0.53:53`. cloud-init
stops/disables/masks it (and dnsmasq, bind9, apache2, nginx if present), then
repairs DNS resolution.

Verify on the host:
```bash
# Nothing should be listening on 53 or 443 yet (before your app starts):
sudo ss -tulpn | grep -E ':53|:443' || echo "53/443 are free"

systemctl is-enabled systemd-resolved   # -> masked
cat /etc/resolv.conf                     # -> nameserver 1.1.1.1 / 8.8.8.8
```

<details>
<summary>The manual equivalent of freeing the ports</summary>

```bash
# See what holds port 53 / 443:
sudo ss -tulpn | grep -E ':53|:443'

# Disable the usual suspects:
for svc in systemd-resolved dnsmasq named bind9 apache2 nginx; do
  sudo systemctl stop "$svc"    2>/dev/null || true
  sudo systemctl disable "$svc" 2>/dev/null || true
  sudo systemctl mask "$svc"    2>/dev/null || true
done

# systemd-resolved managed /etc/resolv.conf via a symlink — replace it so the
# host can still resolve names for apt/upstream lookups:
sudo rm -f /etc/resolv.conf
printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\noptions edns0\n' | sudo tee /etc/resolv.conf
sudo chattr +i /etc/resolv.conf   # optional: stop it being overwritten
```
</details>

### Step 5 — Deploy the application (scp + ssh, env-var driven)

Put your real nameserver/reverse-proxy launch command in [`app/run.sh`](app/run.sh),
then ship it. The deploy script is driven entirely by environment variables:

```bash
SSH_KEY_FILE=~/keys/ssh.key SSH_USER=admin SSH_PORT=22 ./scripts/deploy.sh 203.0.113.10
```

| Env var        | Default              | Meaning                         |
|----------------|----------------------|---------------------------------|
| `SSH_KEY_FILE` | `~/.ssh/id_ed25519`  | private key for auth            |
| `SSH_USER`     | `admin`              | remote sudo user                |
| `SSH_PORT`     | `22`                 | remote sshd port                |
| `APP_DIR`      | `./app`              | local dir shipped to the host   |
| `REMOTE_DIR`   | `/opt/nameserver-proxy` | remote install path          |
| `SERVICE_NAME` | `nameserver-proxy`   | systemd unit restarted after upload |

It scp's `app/` to a staging dir, installs it into `/opt/nameserver-proxy`,
grants `CAP_NET_BIND_SERVICE` to ELF binaries (so a non-root process can bind
53/443), and restarts the systemd service.

### Step 6 — Background process: systemd launches the app in tmux on boot

cloud-init installed a **systemd** unit that starts the app inside a **named,
detached tmux session** on every boot, so it survives reboots and you can
attach to watch it live.

```bash
# Is it running?
systemctl status nameserver-proxy

# Reboot test:
sudo reboot
# ...reconnect...
systemctl is-active nameserver-proxy   # -> active
tmux ls                                 # -> nameserver-proxy: 1 windows
```

The service is `Type=forking`, runs as the `admin` user with a stable
`TMUX_TMPDIR=/run/nameserver-proxy`, and runs:
```
tmux new-session -d -s nameserver-proxy '/opt/nameserver-proxy/run.sh; exec bash'
```

### Step 7 — Verify the ports are open and listening

**From the host** (after your real app is deployed and binding the ports):
```bash
sudo ss -tulpn | grep -E ':22|:53|:443'
# tcp  LISTEN  ... :22    sshd
# udp  UNCONN  ... :53    <your nameserver>
# tcp  LISTEN  ... :443   <your reverse proxy>
```

**From your laptop** (through the Security Group):
```bash
# SSH
ssh -i ~/keys/ssh.key -p 22 admin@203.0.113.10 true && echo "22 OK"

# DNS over UDP 53 (needs your nameserver answering)
dig @203.0.113.10 example.com +short

# HTTPS 443
curl -k https://203.0.113.10/      # -k while using a self-signed/placeholder cert

# Raw reachability
nc -vz 203.0.113.10 443
nc -vzu 203.0.113.10 53
```

---

## tmux cheat sheet

The app runs in a session named **`nameserver-proxy`**. Default prefix is `Ctrl-b`.

```bash
tmux ls                          # list sessions
tmux a -t nameserver-proxy       # ATTACH to the app session
```

| Action                     | Keys / command                                  |
|----------------------------|-------------------------------------------------|
| Attach to the session      | `tmux a -t nameserver-proxy`                    |
| **Detach** (leave it running) | `Ctrl-b` then `d`                            |
| Enter scroll/copy mode     | `Ctrl-b` then `[`  (arrows / PageUp to scroll)  |
| Exit scroll mode           | `q`                                             |
| New window                 | `Ctrl-b` then `c`                               |
| Next / previous window     | `Ctrl-b` then `n` / `p`                         |
| Kill the session           | `tmux kill-session -t nameserver-proxy`         |

> Detaching (`Ctrl-b d`) leaves the app running in the background — that's the
> whole point. Closing your SSH connection does **not** stop it either.

---

## Attaching your GoDaddy domain (later)

The Elastic IP is your anchor. When you're ready:

1. **Registered nameservers / glue records** (GoDaddy → your domain → *Manage
   DNS* → *Nameservers* / *Host names*): create host records
   `ns1.yourdomain.com` and `ns2.yourdomain.com` both pointing at your
   **Elastic IP**, then set the domain to use those custom nameservers.
2. **A record**: point `@` / `www` at the Elastic IP for the reverse-proxy site.
3. Open **TCP 53** too (`enable_dns_tcp = true`) so large DNS answers and any
   zone transfers work.
4. For real HTTPS, get a certificate (e.g. Let's Encrypt) for the domain and
   load it into your reverse proxy on 443.

`terraform output nameserver_hint` prints the mapping to set up.

---

## CI/CD setup

The pipeline (`.github/workflows/deploy.yml`) runs `fmt`/`validate`/`plan` on
PRs and `apply` on merge to `main`, authenticating to AWS via **OIDC** (no
static keys).

1. In the **`Summer_fun` (647379406056)** account, create an IAM role trusting
   GitHub's OIDC provider (`token.actions.githubusercontent.com`) with
   permissions for VPC/EC2/EIP. Its ARN will look like
   `arn:aws:iam::647379406056:role/<role-name>`.
2. Repo **Settings → Secrets and variables → Actions**:
   - Variables: `AWS_ROLE_ARN` (the role above), `AWS_REGION`, `SSH_USER`, `SSH_PORT`.
   - Secrets: `SSH_PUBLIC_KEY` (for `TF_VAR_ssh_public_key`), and
     `SSH_PRIVATE_KEY` if you use the optional app-deploy job.
3. Trigger the optional application deploy via **Run workflow →
   run_app_deploy = true**.

### One-time backend bootstrap (recommended)

So state isn't stored on ephemeral runners, create an S3 bucket + DynamoDB lock
table once, then uncomment the `backend "s3"` block in `versions.tf`:

```bash
aws s3api create-bucket --bucket YOUR-tfstate-bucket --region us-east-1
aws s3api put-bucket-versioning --bucket YOUR-tfstate-bucket \
  --versioning-configuration Status=Enabled
aws dynamodb create-table --table-name YOUR-tf-lock-table \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

---

## Teardown

```bash
cd terraform
terraform destroy
```

## Security notes

- Restrict `ssh_ingress_cidrs` to your IP(s); the default `0.0.0.0/0` is for
  first-time setup only.
- Keys: only the **public** key goes into Terraform; the **private** key stays
  on your machine or in a CI secret. `.gitignore` blocks `*.key`/`*.pem`.
- IMDSv2 is enforced and the root volume is encrypted.
