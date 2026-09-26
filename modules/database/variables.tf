variable "project_name" {
  description = "Short name used as a prefix for all resource names/tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
}

# Passed in from the vpc module's output — this module never creates its own
# networking, it only consumes subnet IDs handed to it. Keeps the dependency
# direction one-way (database depends on vpc, never the reverse).
variable "private_subnet_ids" {
  description = "Private subnet IDs (from the vpc module) to place the DB subnet group in."
  type        = list(string)
}

# Passed in from the security module's output. Same one-way dependency
# principle: database doesn't know or care how the SG's rules are defined,
# only that this ID controls who can reach port 3306.
variable "rds_sg_id" {
  description = "Security group ID (from the security module) to attach to the RDS instance."
  type        = string
}

# Passed in from the kms module's output. Used for both RDS storage
# encryption and the Secrets Manager secret, so this one key ties both
# together — see the kms module's comments for why that's centralized there
# instead of each module creating its own key.
variable "kms_key_arn" {
  description = "ARN of the KMS key (from the kms module) used for RDS storage and secret encryption."
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance size, e.g. db.t3.micro (free-tier eligible) or db.t3.small."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage for the RDS instance, in GB."
  type        = number
  default     = 20
}

variable "engine_version" {
  description = "MySQL engine version."
  type        = string
  default     = "8.0"
}

variable "db_name" {
  description = "Name of the initial database created inside the RDS instance."
  type        = string
}

variable "master_username" {
  description = "Master username for the RDS instance. The password is generated automatically — never hardcoded."
  type        = string
  default     = "admin"
}

# Multi-AZ toggle: when true, AWS provisions a synchronous standby replica in
# a second AZ and handles automatic failover if the primary fails. It roughly
# doubles the RDS cost for the availability guarantee — a real production
# trade-off, not a demo checkbox, which is why it's exposed as a variable
# instead of hardcoded on.
variable "multi_az" {
  description = "Whether to enable Multi-AZ standby replication and automatic failover."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Number of days to retain automated RDS backups."
  type        = number
  default     = 7
}

# Secrets Manager also enforces a recovery/waiting window before a deleted
# secret is gone for good (same idea as the KMS deletion window). 0 disables
# it entirely for fast dev teardown; real environments should keep a buffer.
variable "secret_recovery_window_in_days" {
  description = "Waiting period before a deleted Secrets Manager secret is permanently removed. 0 = immediate deletion (dev only)."
  type        = number
  default     = 0
}

# Guardrail so a stray `terraform destroy` can't silently drop a production
# database. Should be true in prod, false in dev where fast teardown matters
# more than the safety net.
variable "deletion_protection" {
  description = "Whether to enable RDS deletion protection (blocks terraform destroy / console delete)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags merged into every resource in this module."
  type        = map(string)
  default     = {}
}
