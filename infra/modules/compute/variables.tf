variable "name_prefix" {
  description = "Name prefix for compute resources."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t2.micro"
}

variable "subnet_id" {
  description = "Subnet ID."
  type        = string
}

variable "security_group_id" {
  description = "Security group ID."
  type        = string
}

variable "key_pair_name" {
  description = "Existing EC2 key pair name (optional if public_key_material is provided)."
  type        = string
  default     = null

  validation {
    condition = (
      (var.key_pair_name != null && var.key_pair_name != "") ||
      (var.public_key_material != null && var.public_key_material != "")
    )
    error_message = "Provide either key_pair_name or public_key_material."
  }
}

variable "public_key_material" {
  description = "Public key material to create a key pair."
  type        = string
  default     = null
}

variable "user_data" {
  description = "User data script content."
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Root volume size (GB)."
  type        = number
  default     = 30
}

variable "root_volume_type" {
  description = "Root volume type."
  type        = string
  default     = "gp3"
}

variable "ssm_path_prefix" {
  description = "SSM parameter path prefix."
  type        = string
}

variable "kms_key_arn" {
  description = "Optional KMS key ARN for SSM decrypt."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources."
  type        = map(string)
  default     = {}
}
