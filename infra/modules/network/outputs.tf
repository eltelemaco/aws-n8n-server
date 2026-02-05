output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "public_subnet_id" {
  description = "Public subnet ID."
  value       = aws_subnet.public.id
}

output "public_subnet_cidr" {
  description = "Public subnet CIDR."
  value       = aws_subnet.public.cidr_block
}

output "az" {
  description = "Availability zone used."
  value       = aws_subnet.public.availability_zone
}
