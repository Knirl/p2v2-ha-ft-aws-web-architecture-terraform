locals {
  name = "${var.project_name}-${var.environment}"
}

# ---------------------------------------------------------------------------
# The Application Load Balancer. internal = false + public subnets makes
# this the one internet-facing entry point in the whole architecture —
# everything else (compute, database) sits in private subnets and is only
# reachable through the SG chain that starts here.
# ---------------------------------------------------------------------------

resource "aws_lb" "this" {
  name               = "${local.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection

  tags = merge(var.tags, {
    Name = "${local.name}-alb"
  })
}

# ---------------------------------------------------------------------------
# Target Group. target_type = "instance" because targets are registered by
# EC2 instance ID (via the root-level aws_autoscaling_attachment, not by
# this module) — that's what lets the ASG's instances plug into this target
# group without compute and alb ever referencing each other directly.
#
# The health_check block is what actually drives the ASG's "ELB" health
# check type once attached: if a target fails unhealthy_threshold checks
# against health_check_path, the ALB stops sending it traffic AND the ASG
# (because it's set to trust ELB health checks) will eventually terminate
# and replace that instance.
# ---------------------------------------------------------------------------

resource "aws_lb_target_group" "this" {
  name     = "${local.name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  target_type = "instance"

  health_check {
    path                = var.health_check_path
    interval            = var.health_check_interval
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
    matcher             = "200"
  }

  tags = merge(var.tags, {
    Name = "${local.name}-tg"
  })
}

# ---------------------------------------------------------------------------
# HTTP listener on port 80, forwarding everything straight to the target
# group. Kept HTTP-only (no HTTPS/ACM certificate) since this is a
# portfolio/demo build without a real domain to issue a cert for — adding
# an HTTPS listener later would mean adding an aws_acm_certificate,
# validating it via DNS, and adding a second listener on 443, all
# independent of anything else in this module.
# ---------------------------------------------------------------------------

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
