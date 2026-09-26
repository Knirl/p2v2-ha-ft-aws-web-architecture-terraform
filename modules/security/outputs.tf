output "alb_sg_id" {
  description = "Security group ID for the ALB."
  value       = aws_security_group.alb.id
}

output "ec2_sg_id" {
  description = "Security group ID for the EC2 instances."
  value       = aws_security_group.ec2.id
}

output "rds_sg_id" {
  description = "Security group ID for the RDS instance."
  value       = aws_security_group.rds.id
}
