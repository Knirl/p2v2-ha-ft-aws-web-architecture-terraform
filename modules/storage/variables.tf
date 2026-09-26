variable "project_name" {
  description = "Short name used as a prefix for all resource names/tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
}

# Optional. S3 bucket encryption defaults to AES256 (Amazon S3 managed keys,
# free, zero setup) when this is left null. Passing in the kms module's
# key_arn upgrades to SSE-KMS using the same shared CMK the database module
# uses — one key, one place to audit, consistent with the "centralize KMS"
# decision made in the kms module.
variable "kms_key_arn" {
  description = "ARN of a KMS key for SSE-KMS bucket encryption. Leave null to use S3-managed AES256 instead."
  type        = string
  default     = null
}

# This is the stretch-goal toggle from the v2 roadmap: when true, this module
# creates the IAM *policy* granting read/write access to the bucket. It does
# NOT create the role or instance profile — that lives in the compute module,
# which is the thing that actually needs to assume it. Storage only produces
# the policy document/ARN as an output; compute decides whether to attach it.
# This keeps the dependency direction one-way (compute depends on storage's
# output, storage never needs to know compute exists).
variable "enable_ec2_access" {
  description = "Whether to create an IAM policy granting EC2 (via compute's instance profile) read/write access to this bucket."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags merged into every resource in this module."
  type        = map(string)
  default     = {}
}
