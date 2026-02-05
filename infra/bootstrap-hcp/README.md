# Bootstrap HCP Terraform

Creates the HCP Terraform workspace and seeds required variables for the main stack.
This directory uses local state.

## Prerequisites
- Terraform CLI
- HCP Terraform organization + API token in environment variable `TFE_TOKEN`

## Usage
1) Initialize and apply:
	 - `terraform init`
	 - `terraform apply`

2) Provide required variables via `-var` or `TF_VAR_` environment variables:
	 - `tfc_organization`, `tfc_workspace_name`
	 - `admin_ssh_cidr`, `letsencrypt_email`
	 - Secrets: `n8n_encryption_key`, `postgres_password`, `basic_auth_username`,
		 `basic_auth_password`, `portainer_admin_password`

## Notes
- Secrets are marked sensitive and are not stored in the repo.
- If using VCS-driven runs, set `vcs_repo_identifier` and `vcs_oauth_token_id`.
- AWS credentials can be injected as workspace environment variables using
	`aws_access_key_id`, `aws_secret_access_key`, and `aws_session_token`.
