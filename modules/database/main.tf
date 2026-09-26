locals {
  name = "${var.project_name}-${var.environment}"
}


# DB Subnet Group — tells RDS which subnets it's allowed to place ENIs in.
# Always the private subnets: the database should never be directly
# reachable from the internet, only from EC2 via the rds security group.
# Requires at least 2 subnets in different AZs, which is exactly what the
# vpc module always produces (validated there via the `azs` variable).

resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${local.name}-db-subnet-group"
  })
}



# Generate the master password at apply time instead of typing one into a
# .tfvars file. `special = true` with a restricted `override_special` avoids
# characters RDS rejects in passwords (/, @, ", and space are disallowed).
# This value only ever lives in Terraform state (state should be treated as
# sensitive/encrypted — see the S3 backend's encryption config) and in the
# Secrets Manager secret below — never in a variable file or in plain text
# in the repo.

resource "random_password" "master" {
  length           = 20
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>:?"
}



# Secrets Manager container for the credentials. Encrypted with the shared
# CMK from the kms module (rather than the default AWS-managed key) so the
# same key policy/audit trail covers both RDS storage and this secret.
# `recovery_window_in_days` controls how long a *deleted* secret lingers
# before being unrecoverable — set to 0 in dev for fast, clean teardown.

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${local.name}-db-credentials"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.secret_recovery_window_in_days

  tags = merge(var.tags, {
    Name = "${local.name}-db-credentials"
  })
}


# The actual secret payload. Written as a single JSON blob containing
# everything an application needs to connect — username, password, and the
# real RDS endpoint/port pulled straight from the instance below. Because
# this references aws_db_instance.this.address, Terraform automatically
# waits for the RDS instance to finish provisioning before writing the
# secret version (implicit dependency, no explicit depends_on needed).

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master.result
    engine   = "mysql"
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = var.db_name
  })
}



# The RDS instance. Key decisions worth flagging on review:
#   - storage_encrypted + kms_key_id: encryption at rest via the shared CMK.
#   - vpc_security_group_ids: locked to the rds SG, which only trusts the
#     ec2 SG (see the security module) — no other path in.
#   - multi_az: real HA when true, single-AZ when false — see the variable
#     comment for the cost trade-off this represents.
#   - skip_final_snapshot: true only outside prod, so a `terraform destroy`
#     in dev doesn't sit around waiting on (and paying for) a final
#     snapshot nobody will restore; prod always takes one on teardown.
#   - password comes straight from random_password, never a literal.

resource "aws_db_instance" "this" {
  identifier     = "${local.name}-db"
  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.db_instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  db_name  = var.db_name
  username = var.master_username
  password = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_sg_id]

  multi_az                        = var.multi_az
  backup_retention_period         = var.backup_retention_period
  deletion_protection             = var.deletion_protection           #Database won't prevent teardown/destroy
  auto_minor_version_upgrade      = true                              #MySQL doesn't stayo on it's minor version
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"] #view MySQL's error/slow-query logs in CloudWatch instead of it only sitting inside RDS instance itself

  # Dev/portfolio convenience: skip the final snapshot everywhere except
  # prod so teardown is fast and doesn't leave a billed snapshot behind.
  skip_final_snapshot       = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "${local.name}-db-final-snapshot" : null

  tags = merge(var.tags, {
    Name = "${local.name}-db"
  })
}