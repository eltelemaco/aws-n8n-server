output "vpc_id" {
  description = "VPC ID."
  value       = module.network.vpc_id
}

output "public_subnet_id" {
  description = "Public subnet ID."
  value       = module.network.public_subnet_id
}

output "security_group_id" {
  description = "Security group ID."
  value       = module.security.security_group_id
}

output "instance_id" {
  description = "EC2 instance ID."
  value       = module.compute.instance_id
}

output "public_ip" {
  description = "Elastic IP address."
  value       = module.compute.public_ip
}
