variable "project_name" {
  description = "Short name used as a prefix for all resource names/tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
}

# Real deletion is deliberately hard to do by accident in KMS: AWS enforces a
# waiting period (7-30 days) between "schedule deletion" and the key actually
# being destroyed, during which it can still be cancelled/restored. Lower
# values are convenient in dev (faster teardown, less orphaned-key clutter);
# prod should stay high.
variable "key_deletion_window_in_days" {
  description = "Waiting period before the KMS key is permanently deleted after a destroy."
  type        = number
  default     = 7

  validation {
    condition     = var.key_deletion_window_in_days >= 7 && var.key_deletion_window_in_days <= 30
    error_message = "AWS requires the KMS deletion window to be between 7 and 30 days."
  }
}

variable "tags" {
  description = "Common tags merged into every resource in this module."
  type        = map(string)
  default     = {}
}
