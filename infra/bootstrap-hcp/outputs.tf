output "workspace_id" {
  description = "HCP Terraform workspace ID."
  value       = tfe_workspace.this.id
}

output "workspace_name" {
  description = "HCP Terraform workspace name."
  value       = tfe_workspace.this.name
}
