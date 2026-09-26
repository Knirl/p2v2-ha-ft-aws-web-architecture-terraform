variable "project_name" {
  description = "Short name used as a prefix for all resource names/tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
}

# From the vpc module's output. The target group needs to know which VPC
# it's registering targets in (target groups are VPC-scoped resources).
variable "vpc_id" {
  description = "VPC ID (from the vpc module) the target group belongs to."
  type        = string
}

# From the vpc module's output. Public subnets, not private — the ALB is the
# one thing in this whole architecture that's meant to face the internet.
# Everything behind it (EC2, RDS) stays private.
variable "public_subnet_ids" {
  description = "Public subnet IDs (from the vpc module) the ALB is deployed into."
  type        = list(string)
}

# From the security module's output. Only allows inbound HTTP from
# 0.0.0.0/0 — see the security module for the full chain this feeds into.
variable "alb_sg_id" {
  description = "Security group ID (from the security module) attached to the ALB."
  type        = string
}

variable "health_check_path" {
  description = "Path the target group health check requests."
  type        = string
  default     = "/"
}

variable "health_check_interval" {
  description = "Aproximate amount of time, in seconds, between health checks of an individual target."
  type        = number
  default     = 30
}

variable "healthy_threshold" {
  description = "Number of consecutive health check successes required before considering a target healthy"
  type        = number
  default     = 2
}

variable "unhealthy_threshold" {
  description = "Number of consecutive health check failures required before considering a target unhealthy"
  type        = number
  default     = 2
}

# Mirrors the same guardrail pattern as the database module's
# deletion_protection: should be true in prod so a stray `terraform destroy`
# or console click can't take down the public entry point by accident.
variable "enable_deletion_protection" {
  description = "Whether to enable deletion protection on the ALB."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags merged into every resource in this module."
  type        = map(string)
  default     = {}
}
