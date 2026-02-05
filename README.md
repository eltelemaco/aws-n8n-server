# aws-n8n-server

Automated n8n deployment on AWS EC2 with Docker, Traefik, and Terraform.

## Overview

This repository provisions a complete n8n workflow automation platform on a single AWS EC2 instance (free-tier oriented). It uses:

- **Terraform** with HCP Terraform remote state for infrastructure management
- **Docker Compose** for containerized services
- **Traefik** as reverse proxy with automatic Let's Encrypt TLS certificates
- **n8n** in queue mode with PostgreSQL and Redis
- **Portainer** for container management UI

### Architecture Diagram

```text
                                    ┌─────────────────────────────────────────────────┐
                                    │              AWS (us-east-1)                    │
                                    │                                                 │
┌──────────────┐                    │  ┌───────────────────────────────────────────┐  │
│   Internet   │                    │  │             VPC (10.10.0.0/16)            │  │
│              │                    │  │                                           │  │
│  ┌────────┐  │    HTTPS (443)     │  │  ┌─────────────────────────────────────┐  │  │
│  │ Users  │──┼────────────────────┼──┼─▶│     Public Subnet (10.10.1.0/24)    │  │  │
│  └────────┘  │                    │  │  │                                     │  │  │
│              │                    │  │  │  ┌─────────────────────────────────┐│  │  │
│  ┌────────┐  │    Webhooks        │  │  │  │   EC2 (t2.micro) + Elastic IP   ││  │  │
│  │External│──┼────────────────────┼──┼─▶│  │                                 ││  │  │
│  │Services│  │                    │  │  │  │  ┌─────────────────────────┐    ││  │  │
│  └────────┘  │                    │  │  │  │  │    Docker Containers    │    ││  │  │
│              │                    │  │  │  │  │                         │    ││  │  │
└──────────────┘                    │  │  │  │  │  traefik (:80/:443)     │    ││  │  │
                                    │  │  │  │  │  n8n (main + worker)    │    ││  │  │
┌──────────────┐                    │  │  │  │  │  postgres              │    ││  │  │
│  HCP Terraform│                   │  │  │  │  │  redis                 │    ││  │  │
│  (Remote State)│                  │  │  │  │  │  portainer             │    ││  │  │
└──────────────┘                    │  │  │  │  └─────────────────────────┘    ││  │  │
       │                            │  │  │  └─────────────────────────────────┘│  │  │
       │                            │  │  └─────────────────────────────────────┘  │  │
       ▼                            │  └───────────────────────────────────────────┘  │
┌──────────────┐                    │                                                 │
│ AWS SSM      │◀───────────────────│  EC2 fetches secrets at boot via IAM role      │
│ Parameter    │                    │                                                 │
│ Store        │                    └─────────────────────────────────────────────────┘
└──────────────┘
```

### Service URLs

| Service | URL | Description |
|---------|-----|-------------|
| n8n | `https://domain.com/n8n` | Workflow automation UI |
| Portainer | `https://domain.com/portainer` | Container management UI |
| Webhooks | `https://domain.com/n8n/webhook/*` | n8n webhook endpoints (no auth) |

### Secrets Flow

```text
HCP Terraform Variables (sensitive)
         │
         ▼
AWS SSM Parameter Store (SecureString)
         │
         ▼
EC2 Instance (fetched at boot via IAM role)
         │
         ▼
.env file (chmod 600, in /opt/stacks/n8n)
```

Secrets are **never** committed to the repository or embedded in user_data.

---

## Prerequisites

### Required

1. **AWS Account** with permissions to create:
   - VPC, Subnets, Internet Gateway, Route Tables
   - EC2 instances, Elastic IPs, Key Pairs
   - IAM Roles, Policies, Instance Profiles
   - SSM Parameters
   - Security Groups

2. **HCP Terraform Account**
   - Organization created
   - API token generated ([User Settings > Tokens](https://app.terraform.io/app/settings/tokens))

3. **Terraform CLI** >= 1.6.0
   - [Install Terraform](https://developer.hashicorp.com/terraform/downloads)

4. **Domain Name** with DNS management access
   - Default: `domain.com`
   - You'll need to create an A record pointing to the Elastic IP

5. **SSH Key Pair** (one of):
   - Existing EC2 key pair name in us-east-1
   - OR public key material to create a new key pair

### Optional

- **1Password CLI** (`op`) for local secrets management (see `.env.op`)
- **AWS CLI** for debugging and manual SSM access

---

## Quick Start

### Step 1: Clone the Repository

```bash
git clone https://github.com/your-org/aws-n8n-server.git
cd aws-n8n-server
```

### Step 2: Configure HCP Terraform Token

```bash
export TF_TOKEN_app_terraform_io="your-hcp-terraform-token"
```

Or add to `~/.terraformrc`:

```hcl
credentials "app.terraform.io" {
  token = "your-hcp-terraform-token"
}
```

### Step 3: Bootstrap HCP Workspace

The bootstrap stack creates the HCP Terraform workspace and configures all required variables.

```bash
cd infra/bootstrap-hcp

# Create terraform.tfvars with your values
cat > terraform.tfvars << 'EOF'
tfc_organization       = "YourOrganization"
tfc_workspace_name     = "n8n-workspace-east1"
aws_region             = "us-east-1"
admin_ssh_cidr         = "YOUR_IP/32"
public_key_material    = "ssh-ed25519 AAAA... your-key"
domain_name            = "domain.com"
letsencrypt_email      = "admin@example.com"
ssm_path_prefix        = "/n8n/prod"

# Secrets (use environment variables or 1Password for production)
n8n_encryption_key         = "your-32-char-encryption-key-here"
postgres_password          = "strong-postgres-password"
basic_auth_username        = "admin"
basic_auth_password        = "strong-basic-auth-password"
portainer_admin_password   = "strong-portainer-password"
EOF

# Initialize and apply
make bootstrap
# Or manually:
# terraform init
# terraform apply
```

### Step 4: Deploy Infrastructure

```bash
cd ../live/prod

# Initialize with remote backend
make init

# Review the plan
make plan

# Apply (creates all AWS resources)
make apply
```

### Step 5: Configure DNS

After `terraform apply` completes, note the Elastic IP from the output:

```bash
terraform output public_ip
```

Create an **A record** in your DNS provider:

```text
domain.com  →  <ELASTIC_IP>
```

### Step 6: Verify Deployment

Wait 3-5 minutes for the EC2 instance to boot and start all services.

1. **Check n8n**: `https://domain.com/n8n`
2. **Check Portainer**: `https://domain.com/portainer`

You'll be prompted for basic auth credentials (the ones you configured).

> **Note**: Initially you'll see a Let's Encrypt **staging certificate** warning. This is expected. See [Switching to Production Certificates](#switching-to-production-certificates) once you've verified everything works.

---

## Configuration Reference

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `admin_ssh_cidr` | CIDR allowed for SSH access | `1.2.3.4/32` |
| `letsencrypt_email` | Email for Let's Encrypt notifications | `admin@example.com` |
| `n8n_encryption_key` | n8n encryption key (32+ chars) | `abcdef1234567890...` |
| `postgres_password` | PostgreSQL password | `strong-password` |
| `basic_auth_username` | Basic auth username for UI | `admin` |
| `basic_auth_password` | Basic auth password for UI | `strong-password` |
| `portainer_admin_password` | Portainer admin password | `strong-password` |

### Optional Variables (with defaults)

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | AWS region |
| `domain_name` | `domain.com` | Domain for services |
| `acme_ca_server` | Let's Encrypt Staging | ACME server URL |
| `instance_type` | `t2.micro` | EC2 instance type |
| `root_volume_size` | `30` | Root volume size (GB) |
| `ssm_path_prefix` | `/n8n/prod` | SSM parameter path prefix |

---

## Operations Guide

### SSH Access

Two users are available for SSH access:

| User        | Description                                                    |
|-------------|----------------------------------------------------------------|
| `ec2-user`  | Default Amazon Linux user                                      |
| `telemaco`  | Custom user with sudo privileges and docker group membership   |

```bash
# Connect as ec2-user (default)
ssh -i /path/to/your-key.pem ec2-user@<ELASTIC_IP>

# Connect as telemaco (recommended)
ssh -i /path/to/your-key.pem telemaco@<ELASTIC_IP>
```

Both users use the same SSH key (`public_key_material`). SSH access is restricted to the CIDR specified in `admin_ssh_cidr`.

The `telemaco` user has:

- **sudo privileges** via `wheel` group membership
- **docker access** via `docker` group membership (can run docker commands without sudo)

### File Locations on Instance

| Path | Contents |
|------|----------|
| `/opt/stacks/n8n/` | Main application directory |
| `/opt/stacks/n8n/.env` | Environment variables (chmod 600) |
| `/opt/stacks/n8n/docker-compose.yml` | Docker Compose configuration |
| `/opt/stacks/n8n/traefik/acme.json` | Let's Encrypt certificates (chmod 600) |
| `/opt/stacks/n8n/secrets/htpasswd` | Basic auth credentials (chmod 600) |

### Viewing Logs

```bash
# SSH into the instance first
ssh -i /path/to/key.pem ec2-user@<ELASTIC_IP>

# View all container logs
cd /opt/stacks/n8n
docker compose logs -f

# View specific service logs
docker compose logs -f n8n
docker compose logs -f traefik
docker compose logs -f postgres

# View systemd service status
systemctl status n8n-stack
```

### Restarting Services

```bash
cd /opt/stacks/n8n

# Restart all services
docker compose restart

# Restart specific service
docker compose restart n8n

# Full stop and start
docker compose down
docker compose up -d
```

### Switching to Production Certificates

By default, Let's Encrypt **staging** certificates are used. Once you've verified the deployment works:

1. **Update the variable** in HCP Terraform workspace or terraform.tfvars:

   ```hcl
   acme_ca_server = "https://acme-v02.api.letsencrypt.org/directory"
   ```

2. **Apply the change**:

   ```bash
   make apply
   ```

3. **SSH into the instance** and remove the old staging certificate:

   ```bash
   ssh -i /path/to/key.pem ec2-user@<ELASTIC_IP>
   cd /opt/stacks/n8n

   # Stop Traefik
   docker compose stop traefik

   # Remove old certificates
   rm traefik/acme.json
   touch traefik/acme.json
   chmod 600 traefik/acme.json

   # Restart Traefik to obtain new production certificate
   docker compose up -d traefik
   ```

4. **Verify** by visiting `https://domain.com/n8n` - you should see a valid certificate.

### Backup and Restore

#### Backup n8n Data

```bash
ssh -i /path/to/key.pem ec2-user@<ELASTIC_IP>
cd /opt/stacks/n8n

# Stop services
docker compose stop n8n n8n-worker

# Backup PostgreSQL
docker compose exec postgres pg_dump -U n8n n8n > backup_$(date +%Y%m%d).sql

# Backup n8n files
docker compose cp n8n:/.n8n ./n8n_backup_$(date +%Y%m%d)

# Restart services
docker compose start n8n n8n-worker
```

#### Restore from Backup

```bash
# Stop services
docker compose stop n8n n8n-worker

# Restore PostgreSQL
cat backup_20240101.sql | docker compose exec -T postgres psql -U n8n n8n

# Restart services
docker compose start n8n n8n-worker
```

---

## Security

### Network Security

- **SSH (22)**: Restricted to `admin_ssh_cidr` only
- **HTTP (80)**: Open (redirects to HTTPS)
- **HTTPS (443)**: Open (protected by basic auth where appropriate)
- **Egress**: Unrestricted (required for webhooks, package updates)

### Instance Security

- **IMDSv2 Required**: Instance metadata service v2 enforced (prevents SSRF attacks)
- **EBS Encryption**: Root volume encrypted at rest
- **IAM Least Privilege**: Instance role only has SSM:GetParameter access

### Application Security

- **Basic Auth**: Protects n8n UI and Portainer
- **Webhook Bypass**: `/n8n/webhook*` paths bypass basic auth (required for integrations)
- **HTTPS Only**: All traffic encrypted via Let's Encrypt
- **Secrets Management**: No secrets in code; fetched from SSM at boot

### Files Permissions

| File | Permissions | Reason |
|------|-------------|--------|
| `.env` | `600` | Contains database passwords |
| `acme.json` | `600` | Required by Traefik for cert storage |
| `htpasswd` | `600` | Contains hashed passwords |

---

## Troubleshooting

### Services Not Starting

1. **Check cloud-init logs**:

   ```bash
   sudo cat /var/log/cloud-init-output.log
   ```

2. **Check systemd service**:

   ```bash
   systemctl status n8n-stack
   journalctl -u n8n-stack -f
   ```

3. **Check Docker containers**:

   ```bash
   cd /opt/stacks/n8n
   docker compose ps
   docker compose logs
   ```

### Certificate Issues

1. **Verify DNS is pointing to the Elastic IP**:

   ```bash
   dig domain.com +short
   ```

2. **Check Traefik logs**:

   ```bash
   docker compose logs traefik | grep -i acme
   ```

3. **Verify acme.json permissions**:

   ```bash
   ls -la /opt/stacks/n8n/traefik/acme.json
   # Should be -rw------- (600)
   ```

### n8n Webhooks Not Working

1. **Verify webhook URLs bypass auth** - they should not require basic auth

2. **Check n8n logs**:

   ```bash
   docker compose logs n8n | grep webhook
   ```

3. **Test webhook endpoint**:

   ```bash
   curl -I https://domain.com/n8n/webhook/test
   # Should return 404 or 200, NOT 401 Unauthorized
   ```

### SSM Parameter Access Issues

1. **Verify IAM role is attached**:

   ```bash
   curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
   ```

2. **Test SSM access manually**:

   ```bash
   aws ssm get-parameter --name "/n8n/prod/domain_name" --with-decryption
   ```

---

## Makefile Commands

| Command | Description |
|---------|-------------|
| `make help` | Show available commands |
| `make bootstrap` | Initialize and apply HCP workspace |
| `make bootstrap-init` | Initialize bootstrap terraform |
| `make bootstrap-plan` | Plan bootstrap changes |
| `make bootstrap-apply` | Apply bootstrap changes |
| `make init` | Initialize main terraform |
| `make plan` | Plan infrastructure changes |
| `make apply` | Apply infrastructure changes |
| `make destroy` | Destroy infrastructure (with confirmation) |
| `make fmt` | Format all terraform files |
| `make validate` | Validate terraform configuration |
| `make clean` | Remove .terraform directories |

---

## Repository Structure

```text
.
├── README.md                          # This file
├── Makefile                           # Common commands
├── .gitignore                         # Git ignore patterns
├── .editorconfig                      # Editor configuration
├── .env.op                            # 1Password integration (optional)
├── .github/
│   ├── instructions/
│   │   └── copilot-instructions.md    # AI assistant instructions
│   ├── prompts/
│   │   └── general.prompt.md          # Project specification
│   └── workflows/
│       └── terraform-ci.yml           # CI workflow
└── infra/
    ├── bootstrap-hcp/                 # HCP workspace bootstrap (local state)
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── README.md
    ├── live/
    │   └── prod/                      # Main infrastructure (remote state)
    │       ├── main.tf
    │       ├── backend.tf
    │       ├── providers.tf
    │       ├── versions.tf
    │       ├── variables.tf
    │       ├── outputs.tf
    │       ├── locals.tf
    │       └── user_data/
    │           ├── cloud-init.sh.tftpl
    │           ├── docker-compose.yml.tftpl
    │           └── systemd-service.tftpl
    └── modules/
        ├── network/                   # VPC, subnet, IGW, routes
        ├── security/                  # Security groups
        ├── compute/                   # EC2, EIP, IAM
        └── ssm/                       # SSM parameters
```

---

## License

MIT License - See [LICENSE](LICENSE) for details.

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `make fmt` and `make validate`
5. Submit a pull request

All PRs must pass the CI checks (terraform fmt, validate, and security scans).
