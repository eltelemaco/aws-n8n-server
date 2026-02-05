output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Elastic IP address."
  value       = aws_eip.this.public_ip
}

output "eip_allocation_id" {
  description = "EIP allocation ID."
  value       = aws_eip.this.id
}

output "iam_role_name" {
  description = "IAM role name attached to the instance."
  value       = aws_iam_role.this.name
}
