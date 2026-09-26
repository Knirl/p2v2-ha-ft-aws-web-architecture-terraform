
# Common tags merged into every module call below. Centralized here so
# changing the tagging scheme is a one-line edit instead of hunting through separate module blocks. 

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}


# VPC — no dependencies on any other module. Every other module either
# consumes its subnet IDs directly or depends on something that does.

module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway

  tags = local.common_tags
}


# Security — only depends on vpc.vpc_id. Produces the three chained SG IDs
# that alb, compute, and database each consume individually below.


module "security" {
  source = "./modules/security"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  tags         = local.common_tags
}


# KMS — no dependencies. Its key_arn output fans out to both database and
# (optionally) storage below, which is the entire reason this key lives in
# its own module instead of being created inside database.


module "kms" {
  source = "./modules/kms"

  project_name                = var.project_name
  environment                 = var.environment
  key_deletion_window_in_days = var.kms_key_deletion_window_in_days
  tags                        = local.common_tags
}


# Database — depends on vpc (subnets), security (rds_sg_id), and kms (key_arn). 
# Three separate module outputs converging into one resource is exactly the kind of wiring that would be invisible/hardcoded in a v1-style
# here it's explicit at the one place (root) that's allowed to know about every module at once.


module "database" {
  source = "./modules/database"

  project_name                   = var.project_name
  environment                    = var.environment
  private_subnet_ids             = module.vpc.private_subnet_ids
  rds_sg_id                      = module.security.rds_sg_id
  kms_key_arn                    = module.kms.key_arn
  db_instance_class              = var.db_instance_class
  allocated_storage              = var.db_allocated_storage
  engine_version                 = var.db_engine_version
  db_name                        = var.db_name
  master_username                = var.db_master_username
  multi_az                       = var.rds_multi_az
  backup_retention_period        = var.db_backup_retention_period
  secret_recovery_window_in_days = var.secret_recovery_window_in_days
  deletion_protection            = var.db_deletion_protection
  tags                           = local.common_tags
}


# Storage — kms_key_arn is only passed in when var.storage_use_kms is true;
# otherwise the module falls back to its own AES256 default (see the
# storage module's variable comments). enable_ec2_access is the stretch-goal
# toggle: flipping it on is what causes storage to create the IAM policy
# that compute (below) then attaches to its instance role.


module "storage" {
  source = "./modules/storage"

  project_name      = var.project_name
  environment       = var.environment
  kms_key_arn       = var.storage_use_kms ? module.kms.key_arn : null
  enable_ec2_access = var.enable_ec2_s3_access
  tags              = local.common_tags
}


# Compute — depends on vpc (subnets), security (ec2_sg_id), and storage
# (ec2_access_policy_arn). Note what's NOT passed in: no target_group_arn,
# no alb reference of any kind. Compute has zero awareness that alb exists —
# see the aws_autoscaling_attachment resource at the bottom of this file for
# how the two actually get connected.


module "compute" {
  source = "./modules/compute"

  project_name           = var.project_name
  environment            = var.environment
  private_subnet_ids     = module.vpc.private_subnet_ids
  ec2_sg_id              = module.security.ec2_sg_id
  instance_type          = var.instance_type
  ami_id                 = var.ami_id
  min_size               = var.asg_min_size
  max_size               = var.asg_max_size
  desired_capacity       = var.asg_desired_capacity
  target_cpu_utilization = var.target_cpu_utilization
  storage_ec2_policy_arn = module.storage.ec2_access_policy_arn
  attach_storage_policy  = var.enable_ec2_s3_access
  s3_bucket_name         = module.storage.bucket_id # NEW: Pass S3 bucket name so User Data knows where to pull assets

  tags = local.common_tags
}



# ALB — depends on vpc (public subnets + vpc_id) and security (alb_sg_id).
# Same as compute above: this module has zero awareness that compute or its
# ASG exists.


module "alb" {
  source = "./modules/alb"

  project_name               = var.project_name
  environment                = var.environment
  public_subnet_ids          = module.vpc.public_subnet_ids
  vpc_id                     = module.vpc.vpc_id
  alb_sg_id                  = module.security.alb_sg_id
  health_check_path          = var.health_check_path
  enable_deletion_protection = var.alb_deletion_protection
  tags                       = local.common_tags
}


# THE DECOUPLING POINT. This is the one resource in the entire configuration
# that knows both compute and alb exist — and it's deliberately not inside
# either module. It's the Terraform equivalent of the roadmap's "decouple
# ASG and ALB module dependencies" item: instead of compute importing alb's
# target_group_arn (or alb importing compute's asg_name) as a hard module
# input, the two are wired together here, one level up, by something that's
# allowed to know about both.
#
# Practically, this also means either module could be destroyed and
# recreated independently without the other module's source code needing to
# change — only this one attachment resource would need to be reapplied.

resource "aws_autoscaling_attachment" "asg_alb" {
  autoscaling_group_name = module.compute.asg_name
  lb_target_group_arn    = module.alb.target_group_arn
}


# Observability — depends on alb (arn_suffix outputs for the alarm/dashboard
# dimensions) and compute (asg_name for the CPU widget). Built last since it
# has the most cross-module dependencies of anything in the configuration.

module "observability" {
  source = "./modules/observability"

  project_name            = var.project_name
  environment             = var.environment
  alert_email             = var.alert_email
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
  asg_name                = module.compute.asg_name
  tags                    = local.common_tags
}
