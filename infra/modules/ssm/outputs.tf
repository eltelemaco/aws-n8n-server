output "parameter_names" {
  description = "SSM parameter names created."
  value = {
    postgres_password        = aws_ssm_parameter.postgres_password.name
    n8n_encryption_key       = aws_ssm_parameter.n8n_encryption_key.name
    basic_auth_username      = aws_ssm_parameter.basic_auth_username.name
    basic_auth_password      = aws_ssm_parameter.basic_auth_password.name
    portainer_admin_password = aws_ssm_parameter.portainer_admin_password.name
    letsencrypt_email        = aws_ssm_parameter.letsencrypt_email.name
    domain_name              = aws_ssm_parameter.domain_name.name
    acme_ca_server           = aws_ssm_parameter.acme_ca_server.name
  }
}
