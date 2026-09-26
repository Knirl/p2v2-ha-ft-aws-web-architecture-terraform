output "bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = aws_s3_bucket.this.arn
}

output "bucket_id" {
  description = "Name (ID) of the S3 bucket."
  value       = aws_s3_bucket.this.id
}

# null when enable_ec2_access = false, so the compute module can safely check
# `storage_ec2_policy_arn != null` before deciding whether to attach anything
# to its instance profile.
output "ec2_access_policy_arn" {
  description = "ARN of the IAM policy granting EC2 read/write access to this bucket, or null if enable_ec2_access is false."
  value       = var.enable_ec2_access ? aws_iam_policy.ec2_access[0].arn : null
}
