locals {
  name = "${var.project_name}-${var.environment}"
}

# ---------------------------------------------------------------------------
# SNS topic that CloudWatch alarms publish to. Kept as a separate, reusable
# topic (rather than wiring the alarm directly to an email) so future
# alarms — or a second subscriber like a Slack webhook via Lambda — can
# fan out from this one topic without touching the alarm resource at all.
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "alerts" {
  name = "${local.name}-alerts"

  tags = merge(var.tags, {
    Name = "${local.name}-alerts"
  })
}

# ---------------------------------------------------------------------------
# Email subscription. Worth knowing for review: AWS sends a confirmation
# email to var.alert_email immediately after this is created, and the
# subscription sits in "PendingConfirmation" state — delivering nothing —
# until that link is clicked. Terraform can't automate that click; it's a
# manual one-time step after the first apply.
# ---------------------------------------------------------------------------

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ---------------------------------------------------------------------------
# The one alarm this module ships with: fires when the ALB's target group
# reports unhealthy hosts. This is deliberately the highest-signal alarm to
# start with — "the load balancer can't find anywhere to send traffic" is
# about as close to "the app is actually down" as a metric gets, versus
# something like CPU which can be high while the app is still perfectly
# healthy.
#
#   - namespace/metric_name/dimensions: identifies exactly which target
#     group's UnHealthyHostCount to watch, using the arn_suffix values (see
#     variable comments for why suffixes and not full ARNs).
#   - evaluation_periods + period: requires 2 consecutive 60-second periods
#     breaching the threshold (2 minutes sustained) before alarming, so a
#     single transient blip during a deploy doesn't page anyone.
#   - alarm_actions / ok_actions: notifies the same SNS topic both when the
#     alarm triggers AND when it recovers, so "all clear" is as visible as
#     the original page.
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${local.name}-unhealthy-hosts"
  alarm_description   = "Triggers when the ALB target group has unhealthy hosts."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.unhealthy_host_threshold
  period              = var.unhealthy_host_period
  evaluation_periods  = var.unhealthy_host_evaluation_periods
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = merge(var.tags, {
    Name = "${local.name}-unhealthy-hosts-alarm"
  })
}

# ---------------------------------------------------------------------------
# A single CloudWatch dashboard with 4 widgets, giving one screen that
# answers "is the app up, is it fast, and is it under load":
#
#   1. RequestCount   — is traffic actually arriving at the ALB
#   2. TargetResponseTime — is the app responding quickly
#   3. Healthy/UnhealthyHostCount — the same signal the alarm above watches,
#      but visualized as a trend rather than a single threshold breach
#   4. EC2 CPUUtilization, scoped to this ASG — is compute under load,
#      which is also what the target-tracking scaling policy reacts to
#
# dashboard_body is a raw CloudWatch dashboard JSON spec, hence jsonencode()
# rather than dedicated Terraform resource types per widget — CloudWatch
# dashboards don't have a more structured Terraform resource than this.
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${local.name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ALB Request Count"
          view   = "timeSeries"
          region = data.aws_region.current.region
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Target Response Time"
          view   = "timeSeries"
          region = data.aws_region.current.region
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "Average" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Healthy vs Unhealthy Hosts"
          view   = "timeSeries"
          region = data.aws_region.current.region
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix, { stat = "Average" }],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix, { stat = "Average" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "EC2 CPU Utilization (ASG)"
          view   = "timeSeries"
          region = data.aws_region.current.region
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.asg_name, { stat = "Average" }]
          ]
        }
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# The dashboard JSON needs an explicit AWS region string per widget — unlike
# most resource arguments, this isn't inferred automatically from the
# provider config. Looking it up via data source keeps the module portable
# across regions instead of hardcoding "us-east-1" or similar.
# ---------------------------------------------------------------------------

data "aws_region" "current" {}
