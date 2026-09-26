# The specific attribute the root module's aws_autoscaling_attachment needs
# to wire this ASG to the alb module's target group — see the note on
# target_group_arns in main.tf for why that attachment lives at root instead
# of inside this module.
output "asg_name" {
  description = "Name of the Auto Scaling Group."
  value       = aws_autoscaling_group.this.name
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group."
  value       = aws_autoscaling_group.this.arn
}

output "launch_template_id" {
  description = "ID of the Launch Template."
  value       = aws_launch_template.this.id
}

output "iam_role_arn" {
  description = "ARN of the EC2 instance IAM role — useful if the root module wants to attach further policies (e.g. a Secrets Manager read policy for DB credentials) outside this module's additional_iam_policy_arns list."
  value       = aws_iam_role.ec2.arn
}
