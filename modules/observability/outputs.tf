output "sns_topic_arn" {
  description = "ARN of the SNS alerts topic — pass this to any other alarm the root module wants to wire up outside this module."
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard, useful for constructing a direct console link."
  value       = aws_cloudwatch_dashboard.this.dashboard_name
}
