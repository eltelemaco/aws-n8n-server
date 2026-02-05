variable "path_prefix" {
  description = "SSM parameter path prefix (e.g., /n8n/prod)."
  type        = string
}

variable "domain_name" {
  description = "Domain name for n8n."
  type        = string
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt."
  type        = string
}

variable "acme_ca_server" {
  description = "ACME CA server URL."
  type        = string
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
