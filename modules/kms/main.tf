locals {
  name = "${var.project_name}-${var.environment}"
}

# ---------------------------------------------------------------------------
# Look up the current account ID so the key policy below can reference the
# account's root principal without hardcoding a 12-digit number anywhere.
# This makes the module portable across accounts (dev/staging/prod) with
# zero changes.
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# Key policy: this is written out explicitly (rather than letting AWS apply
# its implicit default) so the trust model is visible and reviewable in code.
#
# What it does: grants the account's ROOT principal full `kms:*` on the key.
# This is NOT "anyone in the account can do anything" — it hands control to
# IAM. With this statement in place, individual IAM users/roles/policies
# (e.g. the RDS service role, an EC2 instance profile) can be granted access
# to this key through normal IAM policies, without needing to edit the KMS
# key policy itself every time. This is the standard AWS-recommended pattern
# for CMKs consumed by multiple services.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "key_policy" {
  statement {
    sid    = "EnableIAMUserPermissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }
}

# ---------------------------------------------------------------------------
# The Customer Managed Key (CMK) itself. Shared by two consumers:
#   - database module: encrypts RDS storage + the Secrets Manager secret
#   - (future) storage module: could encrypt the S3 bucket the same way
# Centralizing it here (instead of letting each module make its own key)
# means one key to rotate, audit, and pay the ~$1/month KMS fee for.
#
# enable_key_rotation = true turns on AWS's automatic annual key rotation
# (the key ID/ARN never changes — AWS rotates the backing cryptographic
# material behind the scenes). This is a common security-checklist item.
# ---------------------------------------------------------------------------

resource "aws_kms_key" "this" {
  description             = "CMK for ${local.name} — RDS storage + Secrets Manager encryption"
  deletion_window_in_days = var.key_deletion_window_in_days
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.key_policy.json

  tags = merge(var.tags, {
    Name = "${local.name}-key"
  })
}

# ---------------------------------------------------------------------------
# A human-readable alias for the key. Other modules/consumers can reference
# either the key's ARN/ID directly or this alias — the alias just makes the
# key easier to spot in the AWS console (raw key IDs are opaque UUIDs).
# ---------------------------------------------------------------------------

resource "aws_kms_alias" "this" {
  name          = "alias/${local.name}-key"
  target_key_id = aws_kms_key.this.key_id
}
