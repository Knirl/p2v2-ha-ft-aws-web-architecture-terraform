locals {
  name = "${var.project_name}-${var.environment}"
}


# ALB Security Group - only one exposed to public internet

resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "Allows inbound HTTP from the internet; forwards to EC2."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${local.name}-alb-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http_from_internet" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from anywhere"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"

  tags = merge(var.tags, {
    Name = "${local.name}-alb-sg-ingress-http"
  })
}

resource "aws_vpc_security_group_egress_rule" "alb_all_outbound" {
  security_group_id = aws_security_group.alb.id
  description       = "All outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = merge(var.tags, {
    Name = "${local.name}-alb-sg-egress-all"
  })
}

# EC2 Security Group - trusts the ALB SG by reference, not by IP

resource "aws_security_group" "ec2" {
  name        = "${local.name}-ec2-sg"
  description = "Allows inbound HTTP only from the ALB security group."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${local.name}-ec2-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "ec2_http_from_alb" {
  security_group_id            = aws_security_group.ec2.id
  description                  = "HTTP from ALB only"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"

  tags = merge(var.tags, {
    Name = "${local.name}-ec2-sg-ingress-http"
  })
}

resource "aws_vpc_security_group_egress_rule" "ec2_all_outbound" {
  security_group_id = aws_security_group.ec2.id
  description       = "All outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = merge(var.tags, {
    Name = "${local.name}-ec2-sg-egress-all"
  })
}

# RDS Security Group - trusts EC2 SG by reference

resource "aws_security_group" "rds" {
  name        = "${local.name}-rds-sg"
  description = "Allows inbound MySQL only from the EC2 security group."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${local.name}-rds-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "rds_mysql_from_ec2" {
  security_group_id            = aws_security_group.rds.id
  description                  = "MySQL from EC2 only"
  referenced_security_group_id = aws_security_group.ec2.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"

  tags = merge(var.tags, {
    Name = "${local.name}-rds-sg-ingress-mysql"
  })
}

resource "aws_vpc_security_group_egress_rule" "rds_all_outbound" {
  security_group_id = aws_security_group.rds.id
  description       = "All outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = merge(var.tags, {
    Name = "${local.name}-rds-sg-egress-all"
  })
}