# Deliberately NOT exposing username/password here. Anything Terraform
# outputs (even marked sensitive) ends up in state and in `terraform output`
# — consumers that need credentials should read the Secrets Manager secret
# at runtime (that's the entire point of storing them there), not pull them
# through module outputs.
output "db_endpoint" {
  description = "Connection endpoint (host:port) of the RDS instance."
  value       = aws_db_instance.this.endpoint
}

output "db_address" {
  description = "Hostname (without port) of the RDS instance."
  value       = aws_db_instance.this.address
}

output "db_instance_id" {
  description = "Resource ID of the RDS instance."
  value       = aws_db_instance.this.id
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret holding DB credentials — pass this to compute's IAM instance profile so EC2 can read it at boot."
  value       = aws_secretsmanager_secret.db_credentials.arn
}
