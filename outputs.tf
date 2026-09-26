# ---------------------------------------------------------------------------
# The one output you'll actually use most often: paste this into a browser
# after `terraform apply` to hit the app through the ALB. Refresh a few
# times and the "Served by instance" line in the response should rotate
# across whatever instances the ASG is currently running.
# ---------------------------------------------------------------------------

output "app_url" {
  description = "URL of the deployed application (ALB DNS name over HTTP)."
  value       = "http://${module.alb.alb_dns_name}"
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

# ---------------------------------------------------------------------------
# Database connectivity. Only the endpoint is surfaced here — never the
# credentials. See secret_arn below for how to actually retrieve those.
# ---------------------------------------------------------------------------

output "rds_endpoint" {
  description = "Connection endpoint (host:port) of the RDS instance."
  value       = module.database.db_endpoint
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret holding DB credentials. Retrieve the actual username/password with: aws secretsmanager get-secret-value --secret-id <this-arn>"
  value       = module.database.secret_arn
}

output "asg_name" {
  description = "Name of the Auto Scaling Group — useful for CLI ops, e.g. `aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names <this>` or manually triggering an instance refresh."
  value       = module.compute.asg_name
}

# ---------------------------------------------------------------------------
# Only populated when var.enable_ec2_s3_access / storage_use_kms toggles are
# relevant — the bucket itself always exists, but whether EC2 can actually
# read/write it depends on those variables (see storage module comments).
# ---------------------------------------------------------------------------

output "s3_bucket_name" {
  description = "Name of the S3 bucket created by the storage module."
  value       = module.storage.bucket_id
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic CloudWatch alarms publish to. Useful if you want to subscribe additional endpoints (e.g. a second email, or a Lambda-backed Slack webhook) outside of Terraform."
  value       = module.observability.sns_topic_arn
}

# ---------------------------------------------------------------------------
# A direct console link, built from the region + dashboard name, so you
# don't have to click through the CloudWatch console manually to find it.
# ---------------------------------------------------------------------------

output "cloudwatch_dashboard_url" {
  description = "Direct URL to the CloudWatch dashboard."
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${module.observability.dashboard_name}"
}
