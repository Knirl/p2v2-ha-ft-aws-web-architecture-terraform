variable "project_name" {
  description = "Short name used as a prefix for all resource names/tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
}

# From the vpc module's output. Instances launch here, never in a public
# subnet — the only public-facing thing in this architecture is the ALB
# (built in the alb module), which forwards traffic in.
variable "private_subnet_ids" {
  description = "Private subnet IDs (from the vpc module) the ASG launches instances into."
  type        = list(string)
}

# From the security module's output. Only trusts inbound HTTP from the ALB
# security group — see the security module for the full chain.
variable "ec2_sg_id" {
  description = "Security group ID (from the security module) attached to each instance."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the launch template."
  type        = string
  default     = "t3.micro"
}

# Optional override. When left null, the module looks up the latest Amazon
# Linux 2023 AMI itself (see the data source in main.tf) instead of you
# having to hunt down and hardcode a region-specific AMI ID that goes has an issue
# the moment AWS ships a new one.
variable "ami_id" {
  description = "AMI ID to use. Leave null to auto-resolve the latest Amazon Linux 2023 AMI."
  type        = string
  default     = null
}

variable "min_size" {
  description = "Minimum number of instances in the Auto Scaling Group."
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances in the Auto Scaling Group."
  type        = number
  default     = 3
}

# Only used to seed the ASG on its first creation. See the lifecycle block
# on aws_autoscaling_group in main.tf — this value is ignored on later
# applies so a scaling event doesn't get reverted the next time you run
# `terraform apply`.
variable "desired_capacity" {
  description = "Initial desired instance count. Ignored on updates after creation (see lifecycle block)."
  type        = number
  default     = 2
}

variable "target_cpu_utilization" {
  description = "Target average CPU percentage for the target-tracking scaling policy."
  type        = number
  default     = 50
}

# Optional. Passed in from the storage module's `ec2_access_policy_arn`
# output at the root level. Left null, no S3 access is attached — this
# module doesn't know or care whether storage exists unless the root module
# chooses to wire it in.
variable "storage_ec2_policy_arn" {
  description = "ARN of an IAM policy (typically the storage module's S3 access policy) to attach to the instance role. Leave null to skip."
  type        = string
  default     = null
}

# Controls WHETHER the storage policy attachment is created — separate from
# storage_ec2_policy_arn, which controls WHAT ARN it uses. Needed because
# count must be known before anything is built, but the ARN above doesn't
# exist yet on a fresh apply. Pass root's own var.enable_ec2_s3_access here.
variable "attach_storage_policy" {
  description = "Whether to attach the storage policy to the instance role."
  type        = bool
  default     = false
}

# General escape hatch for attaching any other managed/customer IAM policies
# (e.g. a future Secrets Manager read policy for the database credentials)
# without this module needing a dedicated variable for every possible policy.
variable "additional_iam_policy_arns" {
  description = "Extra IAM policy ARNs to attach to the instance role, beyond SSM and the optional storage policy."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags merged into every resource in this module."
  type        = map(string)
  default     = {}
}

variable "s3_bucket_name" {
  description = "S3 bucket where the assets will be pulled from."
  type        = string

}

