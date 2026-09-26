variable "project_name" {
  description = "Short name used as a prefix for all resource names/tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "azs" {
  description = "Availability Zones to spread public/private subnets across. Length determines subnet count."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2
    error_message = "At least 2 Availability Zones are required for the HA design."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets. Must be the same length as var.azs."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets. Must be the same length as var.azs."
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Whether to create a NAT Gateway + EIP for private subnet outbound internet access. Off saves ~$32+/month."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags merged into every resource in this module."
  type        = map(string)
  default     = {}
}
