# key_arn is what other modules (database, storage) pass in wherever AWS asks
# for a KMS key reference (e.g. aws_db_instance.kms_key_id, an S3 bucket's
# server-side encryption configuration).
output "key_arn" {
  description = "ARN of the KMS key."
  value       = aws_kms_key.this.arn
}

output "key_id" {
  description = "ID of the KMS key."
  value       = aws_kms_key.this.key_id
}

output "alias_arn" {
  description = "ARN of the KMS key's human-readable alias."
  value       = aws_kms_alias.this.arn
}
