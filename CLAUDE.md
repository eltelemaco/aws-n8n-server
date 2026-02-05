# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repo deploys n8n workflow automation on a single AWS EC2 instance (free-tier oriented) with Docker + Traefik reverse proxy, using Terraform and HCP Terraform remote state.

**Domain**: `n8n.telemaco.com.mx` with path-based routing (`/n8n`, `/portainer`)

## Common Commands

All commands from the project root:

```bash
# Bootstrap HCP Terraform workspace (first-time setup, uses local state)
make bootstrap

# Main infrastructure commands (uses HCP remote state)
make init        # Initialize terraform
make plan        # Plan changes
make apply       # Apply infrastructure
make destroy     # Destroy with confirmation

# Development
make fmt         # Format all terraform files
make validate    # Validate terraform configuration
make clean       # Remove .terraform directories
```

## Architecture

### Secrets Flow (Critical)

```
HCP Terraform Variables (sensitive) → AWS SSM Parameter Store (SecureString) → EC2 at boot via IAM role → .env file (chmod 600)
```

**Never commit secrets or place them in user_data templates.**

### Two-Stage Terraform

1. **Bootstrap** (`infra/bootstrap-hcp/`): Creates HCP Terraform workspace using `tfe` provider with **local state**
2. **Main** (`infra/live/prod/`): Provisions all AWS resources using **HCP remote state**

### Docker Stack

Services running on EC2: traefik, n8n (main + worker), postgres, redis, portainer

n8n runs in **queue mode** with Postgres + Redis.

## Critical Implementation Patterns

### Traefik Basic Auth (Webhook Exception)

Basic auth protects `/n8n` UI and `/portainer`, but **webhook endpoints must bypass auth**:
- Router A (no auth): `PathPrefix(/n8n/webhook)` paths
- Router B (with auth): All other `/n8n` paths
- Portainer: Always requires auth

### EC2 Bootstrap Sequence

The `cloud-init.sh.tftpl` template:
1. Installs Docker + compose plugin
2. Fetches SSM parameters via IAM role
3. Writes `.env` (chmod 600)
4. Renders docker-compose.yml from template
5. Creates `traefik/acme.json` (chmod 600)
6. Starts services via systemd unit

### Let's Encrypt

Defaults to **staging** CA. Switch to production by changing `acme_ca_server` variable to `https://acme-v02.api.letsencrypt.org/directory`, then remove old `acme.json` and restart traefik.

## Key File Locations

| Location | Purpose |
|----------|---------|
| `infra/live/prod/user_data/*.tftpl` | EC2 bootstrap templates (most complex logic) |
| `infra/modules/{network,security,compute,ssm}/` | Terraform modules |
| `/opt/stacks/n8n/` (on EC2) | Application directory with `.env`, `docker-compose.yml` |

## Required Variables

Set in HCP Terraform workspace or `terraform.tfvars`:
- `admin_ssh_cidr` - CIDR for SSH access
- `public_key_material` - SSH public key
- `letsencrypt_email` - For Let's Encrypt notifications
- `n8n_encryption_key`, `postgres_password`, `basic_auth_*`, `portainer_admin_password` - Secrets

## CI/CD

GitHub Actions (`terraform-ci.yml`) runs `fmt -check` and `validate` on PRs. No auto-apply - deployments happen via HCP Terraform.
