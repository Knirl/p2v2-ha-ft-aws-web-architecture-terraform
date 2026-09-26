variable "project_name" {
  description = "Short name used as a prefix for all resource names/tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
}

variable "alert_email" {
  description = "Email address to subscribe to the SNS alert topic. AWS sends a confirmation link to this address that must be clicked before alerts actually deliver."
  type        = string
}

# From the alb module's arn_suffix outputs — CloudWatch identifies ALB and
# target group metrics by these suffixes, not by full ARNs. See the alb
# module's output comments for why both forms are exposed there.
variable "alb_arn_suffix" {
  description = "ARN suffix of the ALB (from the alb module), used as a CloudWatch metric dimension."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the target group (from the alb module), used as a CloudWatch metric dimension."
  type        = string
}

# From the compute module's output. Used as a dimension for the EC2
# CPUUtilization widget on the dashboard — CloudWatch can filter EC2 metrics
# down to "just the instances in this ASG" via this dimension instead of
# averaging across every instance in the account/region.
variable "asg_name" {
  description = "Name of the Auto Scaling Group (from the compute module), used as a CloudWatch metric dimension."
  type        = string
}

variable "unhealthy_host_threshold" {
  description = "Number of unhealthy hosts that triggers the alarm."
  type        = number
  default     = 1
}

variable "unhealthy_host_evaluation_periods" {
  description = "Consecutive breaching periods required before the alarm fires (avoids paging on a single noisy data point)."
  type        = number
  default     = 2
}

variable "unhealthy_host_period" {
  description = "Length of each evaluation period, in seconds."
  type        = number
  default     = 60
}

variable "tags" {
  description = "Common tags merged into every resource in this module."
  type        = map(string)
  default     = {}
}
