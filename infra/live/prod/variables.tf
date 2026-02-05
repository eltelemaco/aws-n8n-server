variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Name prefix for resources."
  type        = string
  default     = "n8n"
}

variable "admin_ssh_cidr" {
  description = "CIDR allowed to SSH (e.g., 1.2.3.4/32)."
  type        = string

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
  default     = null
}

variable "domain_name" {
  description = "Domain name for n8n."
  type        = string
  default     = "n8n.telemaco.com.mx"
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt registration."
  type        = string
}

variable "acme_ca_server" {
  description = "ACME CA server URL."
  type        = string
  default     = "https://acme-staging-v02.api.letsencrypt.org/directory"
}

variable "ssm_path_prefix" {
  description = "SSM parameter path prefix (e.g., /n8n/prod)."
  type        = string
  default     = "/n8n/prod"
}

variable "n8n_encryption_key" {
  description = "n8n encryption key."
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "Postgres password."
  type        = string
  sensitive   = true
}

variable "basic_auth_username" {
  description = "Basic auth username."
  type        = string
  sensitive   = true
}

variable "basic_auth_password" {
  description = "Basic auth password."
  type        = string
  sensitive   = true
}

variable "portainer_admin_password" {
  description = "Portainer admin password."
  type        = string
  sensitive   = true
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t2.micro"
}

variable "root_volume_size" {
  description = "Root volume size in GB."
  type        = number
  default     = 30
}

variable "root_volume_type" {
  description = "Root volume type."
  type        = string
  default     = "gp3"
}

variable "kms_key_arn" {
  description = "Optional KMS key ARN for SSM decrypt."
  type        = string
  default     = null
}
