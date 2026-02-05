terraform {
  required_version = ">= 1.6.0"
  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.50"
    }
  }
}

provider "tfe" {}

resource "tfe_project" "this" {
  count        = var.tfc_project_name == null ? 0 : 1
  name         = var.tfc_project_name
  organization = var.tfc_organization
}

resource "tfe_workspace" "this" {
  name              = var.tfc_workspace_name
  organization      = var.tfc_organization
  project_id        = var.tfc_project_name == null ? null : tfe_project.this[0].id
  working_directory = "infra/live/prod"
  auto_apply        = false

  dynamic "vcs_repo" {
    for_each = var.vcs_repo_identifier == null ? [] : [var.vcs_repo_identifier]
    content {
      identifier     = vcs_repo.value
      branch         = var.vcs_repo_branch
      oauth_token_id = var.vcs_oauth_token_id
    }
  }
}

locals {
  terraform_vars = {
    aws_region = {
      value     = var.aws_region
      sensitive = false
    }
    admin_ssh_cidr = {
      value     = var.admin_ssh_cidr
      sensitive = false
    }
    ec2_key_pair_name = {
      value     = var.ec2_key_pair_name
      sensitive = false
    }
    public_key_material = {
      value     = var.public_key_material
      sensitive = false
    }
    domain_name = {
      value     = var.domain_name
      sensitive = false
    }
    letsencrypt_email = {
      value     = var.letsencrypt_email
      sensitive = false
    }
    acme_ca_server = {
      value     = var.acme_ca_server
      sensitive = false
    }
    ssm_path_prefix = {
      value     = var.ssm_path_prefix
      sensitive = false
    }
    n8n_encryption_key = {
      value     = var.n8n_encryption_key
      sensitive = true
    }
    postgres_password = {
      value     = var.postgres_password
      sensitive = true
    }
    basic_auth_username = {
      value     = var.basic_auth_username
      sensitive = true
    }
    basic_auth_password = {
      value     = var.basic_auth_password
      sensitive = true
    }
    portainer_admin_password = {
      value     = var.portainer_admin_password
      sensitive = true
    }
  }

  env_vars = {
    TFC_AWS_PROVIDER_AUTH = {
      value     = var.tfc_aws_provider_auth == null ? null : tostring(var.tfc_aws_provider_auth)
      sensitive = false
    }
    TFC_AWS_RUN_ROLE_ARN = {
      value     = var.tfc_aws_run_role_arn
      sensitive = false
    }
    AWS_ACCESS_KEY_ID = {
      value     = var.aws_access_key_id
      sensitive = true
    }
    AWS_SECRET_ACCESS_KEY = {
      value     = var.aws_secret_access_key
      sensitive = true
    }
    AWS_SESSION_TOKEN = {
      value     = var.aws_session_token
      sensitive = true
    }
  }

  terraform_vars_filtered = {
    for key, item in local.terraform_vars : key => item
    if nonsensitive(item.value) != null && nonsensitive(item.value) != ""
  }

  env_vars_filtered = {
    for key, item in local.env_vars : key => item
    if nonsensitive(item.value) != null && nonsensitive(item.value) != ""
  }
}

resource "tfe_variable" "terraform" {
  for_each     = nonsensitive(local.terraform_vars_filtered)
  workspace_id = tfe_workspace.this.id
  key          = each.key
  value        = each.value.value
  category     = "terraform"
  sensitive    = each.value.sensitive
  hcl          = false
}

resource "tfe_variable" "env" {
  for_each     = nonsensitive(local.env_vars_filtered)
  workspace_id = tfe_workspace.this.id
  key          = each.key
  value        = each.value.value
  category     = "env"
  sensitive    = each.value.sensitive
  hcl          = false
}
