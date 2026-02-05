module "network" {
  source             = "../../modules/network"
  name_prefix        = local.name_prefix
  vpc_cidr           = "10.10.0.0/16"
  public_subnet_cidr = "10.10.1.0/24"
  tags               = local.tags
}

module "security" {
  source         = "../../modules/security"
  name_prefix    = local.name_prefix
  vpc_id         = module.network.vpc_id
  admin_ssh_cidr = var.admin_ssh_cidr
  tags           = local.tags
}

module "ssm" {
  source                   = "../../modules/ssm"
  path_prefix              = var.ssm_path_prefix
  domain_name              = var.domain_name
  letsencrypt_email        = var.letsencrypt_email
  acme_ca_server           = var.acme_ca_server
  n8n_encryption_key       = var.n8n_encryption_key
  postgres_password        = var.postgres_password
  basic_auth_username      = var.basic_auth_username
  basic_auth_password      = var.basic_auth_password
  portainer_admin_password = var.portainer_admin_password
}

module "compute" {
  source              = "../../modules/compute"
  name_prefix         = local.name_prefix
  instance_type       = var.instance_type
  subnet_id           = module.network.public_subnet_id
  security_group_id   = module.security.security_group_id
  key_pair_name       = var.ec2_key_pair_name
  public_key_material = var.public_key_material
  user_data           = local.user_data
  root_volume_size    = var.root_volume_size
  root_volume_type    = var.root_volume_type
  ssm_path_prefix     = var.ssm_path_prefix
  kms_key_arn         = var.kms_key_arn
  tags                = local.tags
}
