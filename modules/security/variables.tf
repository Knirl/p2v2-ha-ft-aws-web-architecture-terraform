variable "project_name" {
  description = "Short name used as a prefix for all resource names/tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC these security groups belong to."
  type        = string
}

variable "tags" {
  description = "Common tags merged into every resource in this module."
  type        = map(string)
  default     = {}
}

