locals {
  name = "${var.project_name}-${var.environment}"
}

# Auto-resolve the latest Amazon Linux 2023 AMI in whatever region this is applied to
# Instead of hardcoded AMI ID
# Only used when var.ami_id is left null

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"] #official AWS naming scheme for AMazon Linux 2023
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IAM role the instances assume. Trust policy allows the EC2 service itself to assume this role, nothing else can.

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${local.name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = merge(var.tags, {
    Name = "${local.name}-ec2-role"
  })
}


# AmazonSSMManagedInstanceCore (AWS-managed policy) lets AWS Systems Manager
# Session Manager connect to these instances for a shell — no SSH keypair,
# no open port 22, no bastion host required. This is a deliberate departure
# from v1 (and from most tutorial builds): instances live in a private
# subnet with no inbound SSH path at all, which is the real-world-correct
# way to administer instances that shouldn't be reachable from the internet.

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Wire the S3 bucket into compute
# Only attached when the root module passes in a policy
# ARN (i.e. when storage.enable_ec2_access was turned on). This is the
# "wire the S3 bucket into compute" stretch goal from the roadmap — the
# actual IAM policy document lives in the storage module; this just attaches
# it to the role that storage doesn't know exists.




# ___________________________________________
# FIX: count now checks a plain boolean (attach_storage_policy) instead of
# the computed ARN. storage_ec2_policy_arn traces back to a brand-new IAM
# policy's ARN, which doesn't exist yet on a fresh apply — so checking
# "!= null" on it fails with "Invalid count argument" (count must be known
# before anything is built). A plain boolean passed straight from root's
# own var.enable_ec2_s3_access has no such problem.
resource "aws_iam_role_policy_attachment" "storage_access" {
  count      = var.attach_storage_policy ? 1 : 0
  role       = aws_iam_role.ec2.name
  policy_arn = var.storage_ec2_policy_arn
}

#_____________________________________________






# Escape hatch for any other policies the root module wants to attach
# (e.g. a Secrets Manager read policy for the DB credentials) without this
# module needing a dedicated variable per policy.

resource "aws_iam_role_policy_attachment" "additional" {
  count      = length(var.additional_iam_policy_arns)
  role       = aws_iam_role.ec2.name
  policy_arn = var.additional_iam_policy_arns[count.index]
}

# Instance profile: the actual object EC2 attaches to an instance. The IAM
# role above is the identity; the instance profile is just the container
# that lets EC2 use it.

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.name}-ec2-profile"
  role = aws_iam_role.ec2.name
}


# Launch Template. Key decisions worth flagging on review:
#
#   - metadata_options enforces IMDSv2 (http_tokens = "required"): the older
#     IMDSv1 is a known SSRF vector (an app vulnerability can trick the
#     instance into leaking its own IAM credentials via the metadata
#     service). Requiring session tokens closes that off. http_put_response_
#     hop_limit = 1 additionally blocks the metadata service from being
#     reachable through a container/proxy hop on the instance.
#
#   - user_data runs templates/user_data.sh.tpl through templatefile() so
#     the bootstrap script can reference project_name/environment without
#     duplicating them; see that file for what it actually installs.
#
#   - No target_group_arns here. The ASG below is deliberately NOT wired to
#     any target group inside this module — that attachment is created at
#     the ROOT level via aws_autoscaling_attachment, referencing this
#     module's asg_name output and the alb module's target_group_arn
#     output. Neither module needs to know the other exists — matches the
#     "decouple ASG and ALB" roadmap item exactly.


resource "aws_launch_template" "this" {
  name_prefix   = "${local.name}-lt-"
  image_id      = coalesce(var.ami_id, data.aws_ami.amazon_linux.id)
  instance_type = var.instance_type

  vpc_security_group_ids = [var.ec2_sg_id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = base64encode(templatefile("${path.module}/template/user_data.sh.tpl", {
    project_name = var.project_name
    environment  = var.environment
    bucket_name  = var.s3_bucket_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${local.name}-instance"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name = "${local.name}-volume"
    })
  }

  tags = merge(var.tags, {
    Name = "${local.name}-lt"
  })
}

# ---------------------------------------------------------------------------
# The Auto Scaling Group itself.
#
#   - vpc_zone_identifier: private subnets only — see the private_subnet_ids
#     variable comment.
#   - health_check_type = "ELB": once the root-level attachment wires this
#     ASG to the ALB's target group, the ASG starts trusting the ALB's
#     health checks (not just EC2 status checks) to decide whether an
#     instance is healthy. health_check_grace_period gives new instances
#     time to boot and pass httpd's startup before being judged.
#   - lifecycle.ignore_changes = [desired_capacity]: this is the roadmap
#     item "lifecycle ignore_changes for the ASG." Without it, every
#     `terraform apply` would forcibly reset desired_capacity back to
#     var.desired_capacity, silently undoing any scaling activity (manual
#     or automatic) that happened since the last apply. desired_capacity is
#     only used to seed the ASG on first creation.
#   - The dynamic "tag" block propagates every common tag onto each launched
#     instance individually (propagate_at_launch = true), not just onto the
#     ASG resource itself.
# ---------------------------------------------------------------------------

resource "aws_autoscaling_group" "this" {
  name                = "${local.name}-asg"
  vpc_zone_identifier = var.private_subnet_ids

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = merge(var.tags, { Name = "${local.name}-instance" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# ---------------------------------------------------------------------------
# Target-tracking scaling policy: AWS automatically adds/removes instances
# to keep average CPU across the ASG near target_cpu_utilization, rather
# than you having to hand-write CloudWatch alarms + step scaling policies.
# ---------------------------------------------------------------------------

resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "${local.name}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.target_cpu_utilization
  }
}