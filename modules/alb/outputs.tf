output "alb_dns_name" {
  description = "Public DNS name of the ALB — this is the URL you hit to reach the app."
  value       = aws_lb.this.dns_name
}

output "alb_arn" {
  description = "ARN of the ALB."
  value       = aws_lb.this.arn
}

# arn_suffix is a different format than arn (looks like
# "app/name/id" instead of the full ARN) — it's specifically what
# CloudWatch metric dimensions for ALBs expect (e.g. AWS/ApplicationELB's
# LoadBalancer dimension). The observability module will need this to build
# alarms/dashboard widgets against this ALB.
output "alb_arn_suffix" {
  description = "ARN suffix of the ALB, in the format CloudWatch metric dimensions expect."
  value       = aws_lb.this.arn_suffix
}

output "target_group_arn" {
  description = "ARN of the target group — this is what the root module's aws_autoscaling_attachment wires to the compute module's ASG."
  value       = aws_lb_target_group.this.arn
}

# Same idea as alb_arn_suffix, but for the target group — CloudWatch metrics
# like UnHealthyHostCount are dimensioned by TargetGroup arn_suffix, not the
# full ARN.
output "target_group_arn_suffix" {
  description = "ARN suffix of the target group, in the format CloudWatch metric dimensions expect."
  value       = aws_lb_target_group.this.arn_suffix
}
