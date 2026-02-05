variable "tfc_organization" {
  description = "HCP Terraform organization name."
  type        = string
  default     = "TelemacoInfraLabs"
}

variable "tfc_project_name" {
  description = "Optional HCP Terraform project name."
  type        = string
  default     = "aws-n8n-server"
}

variable "tfc_workspace_name" {
  description = "HCP Terraform workspace name (e.g., n8n-prod-usw1)."
  type        = string
  default     = "n8n-workspace-east1"
}

variable "vcs_repo_identifier" {
  description = "Optional VCS repo identifier (org/name) to connect workspace."
  type        = string
  default     = null
}

variable "vcs_repo_branch" {
  description = "Optional VCS branch name for the workspace."
  type        = string
  default     = null
}

variable "vcs_oauth_token_id" {
  description = "Optional VCS OAuth token ID (required if vcs_repo_identifier is set)."
  type        = string
  default     = null

  validation {
    condition     = var.vcs_repo_identifier == null || var.vcs_oauth_token_id != null
    error_message = "vcs_oauth_token_id is required when vcs_repo_identifier is set."
  }
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "admin_ssh_cidr" {
  description = "CIDR allowed to SSH (e.g., 1.2.3.4/32)."
  type        = string
  default     = "0.0.0.0/0"
  validation {
    condition     = can(cidrnetmask(var.admin_ssh_cidr))
    error_message = "admin_ssh_cidr must be a valid CIDR."
  }
}

variable "ec2_key_pair_name" {
  description = "Existing EC2 key pair name (optional if public_key_material is provided)."
  type        = string
  default     = null

  validation {
    condition = (
      (var.ec2_key_pair_name != null && var.ec2_key_pair_name != "") ||
      (var.public_key_material != null && var.public_key_material != "")
    )
    error_message = "Provide either ec2_key_pair_name or public_key_material."
  }
}

variable "public_key_material" {
  description = "Public key material to create a key pair (optional if ec2_key_pair_name is provided)."
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Domain name for n8n (e.g., n8n.telemaco.com.mx)."
  type        = string
  default     = "n8n.telemaco.com.mx"
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt registration."
  type        = string
  default     = null
}

variable "acme_ca_server" {
  description = "ACME CA server URL (staging by default)."
  type        = string
  default     = "https://acme-staging-v02.api.letsencrypt.org/directory"
}

variable "ssm_path_prefix" {
  description = "SSM parameter path prefix (e.g., /n8n/prod)."
  type        = string
}

variable "n8n_encryption_key" {
  description = "n8n encryption key (32+ chars)."
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "Postgres password."
  type        = string
  sensitive   = true
}

variable "basic_auth_username" {
  description = "Basic auth username for Traefik protected routes."
  type        = string
  sensitive   = true
}

variable "basic_auth_password" {
  description = "Basic auth password for Traefik protected routes."
  type        = string
  sensitive   = true
}

variable "portainer_admin_password" {
  description = "Portainer admin password (will be bcrypt-hashed on boot)."
  type        = string
  sensitive   = true
}

variable "aws_access_key_id" {
  description = "Optional AWS_ACCESS_KEY_ID env var for the workspace."
  type        = string
  default     = null
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "Optional AWS_SECRET_ACCESS_KEY env var for the workspace."
  type        = string
  default     = null
  sensitive   = true
}

variable "aws_session_token" {
  description = "Optional AWS_SESSION_TOKEN env var for the workspace."
  type        = string
  default     = null
  sensitive   = true
}

variable "tfc_aws_provider_auth" {
  description = "Enable HCP Terraform AWS provider auth via OIDC."
  type        = bool
  default     = null
}

variable "tfc_aws_run_role_arn" {
  description = "IAM role ARN for HCP Terraform runs (OIDC)."
  type        = string
  default     = null
}
