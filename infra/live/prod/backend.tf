terraform {
  cloud {
    organization = "TelemacoInfraLabs"
    workspaces {
      name = "n8n-workspace-east1"
    }
  }
}
