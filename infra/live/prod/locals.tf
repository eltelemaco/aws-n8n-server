locals {
  name_prefix = var.name_prefix
  stack_dir   = "/opt/stacks/n8n"

  tags = {
    Project = "aws-n8n-server"
    Stack   = "n8n"
  }

  docker_compose = templatefile("${path.module}/user_data/docker-compose.yml.tftpl", {})
  systemd_unit = templatefile("${path.module}/user_data/systemd-service.tftpl", {
    stack_dir = local.stack_dir
  })

  user_data = templatefile("${path.module}/user_data/cloud-init.sh.tftpl", {
    aws_region          = var.aws_region
    ssm_path_prefix     = var.ssm_path_prefix
    stack_dir           = local.stack_dir
    docker_compose      = local.docker_compose
    systemd_unit        = local.systemd_unit
    public_key_material = var.public_key_material
  })
}
