locals {
  path_prefix = trimsuffix(var.path_prefix, "/")
}

resource "aws_ssm_parameter" "postgres_password" {
  name  = "${local.path_prefix}/postgres_password"
  type  = "SecureString"
  value = var.postgres_password
}

resource "aws_ssm_parameter" "n8n_encryption_key" {
  name  = "${local.path_prefix}/n8n_encryption_key"
  type  = "SecureString"
  value = var.n8n_encryption_key
}

resource "aws_ssm_parameter" "basic_auth_username" {
  name  = "${local.path_prefix}/basic_auth_username"
  type  = "SecureString"
  value = var.basic_auth_username
}

resource "aws_ssm_parameter" "basic_auth_password" {
  name  = "${local.path_prefix}/basic_auth_password"
  type  = "SecureString"
  value = var.basic_auth_password
}

resource "aws_ssm_parameter" "portainer_admin_password" {
  name  = "${local.path_prefix}/portainer_admin_password"
  type  = "SecureString"
  value = var.portainer_admin_password
}

resource "aws_ssm_parameter" "letsencrypt_email" {
  name  = "${local.path_prefix}/letsencrypt_email"
  type  = "String"
  value = var.letsencrypt_email
}

resource "aws_ssm_parameter" "domain_name" {
  name  = "${local.path_prefix}/domain_name"
  type  = "String"
  value = var.domain_name
}

resource "aws_ssm_parameter" "acme_ca_server" {
  name  = "${local.path_prefix}/acme_ca_server"
  type  = "String"
  value = var.acme_ca_server
}
