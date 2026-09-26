locals {
  name = "${var.project_name}-${var.environment}"
}

# ---------------------------------------------------------------------------
# S3 bucket names are globally unique across ALL AWS accounts, not just
# yours — "${local.name}-storage" alone would collide with anyone else who
# ran this same module. A short random suffix makes the bucket name
# effectively collision-proof without you having to pick and hardcode one.
# Uses the same `random` provider the database module already depends on
# (random_password), so no new provider requirement is introduced.
# ---------------------------------------------------------------------------

resource "random_id" "suffix" {
  byte_length = 4
}

# ---------------------------------------------------------------------------
# The bucket itself. Deliberately bare — versioning, encryption, and public
# access blocking are each configured as their own separate resource below.
# This split (current AWS provider best practice, same idea as splitting SG
# rules out in the security module) means each concern can be reviewed,
# changed, or diffed independently instead of being buried in one giant
# bucket resource block.
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "this" {
  bucket = "${local.name}-storage-${random_id.suffix.hex}"

  tags = merge(var.tags, {
    Name = "${local.name}-storage"
  })
}

# ---------------------------------------------------------------------------
# Versioning: keeps prior versions of an object when it's overwritten or
# deleted (a delete just adds a "delete marker," the old version is still
# recoverable). Protects against accidental overwrites/deletes by whatever
# is writing to this bucket (e.g. the EC2 app, if enable_ec2_access is on).
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ---------------------------------------------------------------------------
# Server-side encryption. Two modes depending on whether a KMS key was
# passed in:
#   - kms_key_arn provided  -> SSE-KMS using the shared CMK (auditable via
#     CloudTrail, consistent with the RDS/Secrets Manager encryption story)
#   - kms_key_arn is null   -> SSE-S3 (AES256), Amazon's own managed keys —
#     still encrypted at rest, just without a customer-managed key to audit
# bucket_key_enabled = true reduces KMS API calls (and their cost) when
# SSE-KMS is used, by caching a bucket-level data key for a short time.
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null
  }
}

# ---------------------------------------------------------------------------
# Public access block: belt-and-suspenders against this bucket ever being
# made public, whether by a future bucket policy, an ACL, or a console
# mistake. All four settings on is the AWS-recommended default for any
# bucket that isn't explicitly meant to serve public content (this one
# never is — it's private application storage behind IAM).
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# IAM policy document for EC2 access — only created when enable_ec2_access
# is true. Scoped narrowly on purpose:
#   - s3:ListBucket needs the bucket ARN itself (it lists the bucket, not an
#     object), so it's a separate resources entry
#   - Get/PutObject need the bucket ARN + "/*" (they act on objects inside)
# Splitting these two resource patterns into one statement each is standard
# S3 IAM practice — a single "arn + arn/*" list on one statement working for
# ListBucket would actually be wrong (ListBucket doesn't accept an object-
# level ARN) and is a common beginner mistake worth calling out here.
#
# CORRECTED GAP: when the bucket uses SSE-KMS (kms_key_arn != null), reading
# or writing an object requires BOTH the S3 permission above AND a KMS
# permission on the actual key — S3 will refuse the request with
# AccessDenied if only the S3 side is granted, even though the S3 policy
# looks sufficient on its own. This dynamic block adds that KMS statement
# only when SSE-KMS is actually in use; when kms_key_arn is null (SSE-S3 /
# AES256), no KMS statement is needed at all, since Amazon's own managed
# key requires no IAM grant to use.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_access" {
  count = var.enable_ec2_access ? 1 : 0

  statement {
    sid       = "AllowListBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.this.arn]
  }

  statement {
    sid       = "AllowObjectReadWrite"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]
  }

  dynamic "statement" {
    for_each = var.kms_key_arn != null ? [1] : []
    content {
      sid    = "AllowKmsForS3"
      effect = "Allow"
      # Decrypt: needed to read (GetObject) an SSE-KMS encrypted object.
      # GenerateDataKey: needed to write (PutObject) a new SSE-KMS encrypted
      # object — S3 asks KMS to generate a fresh data key for every object
      # it encrypts.
      actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
      resources = [var.kms_key_arn]
    }
  }
}

# ---------------------------------------------------------------------------
# The standalone IAM policy (not attached to anything yet). It's just
# created and its ARN exposed as an output — the compute module is
# responsible for creating the IAM role/instance profile and attaching this
# policy to it. Storage never creates a role, so it never needs to know
# anything about EC2, ASGs, or launch templates.
# ---------------------------------------------------------------------------

resource "aws_iam_policy" "ec2_access" {
  count       = var.enable_ec2_access ? 1 : 0
  name        = "${local.name}-ec2-s3-access"
  description = "Grants read/write access to the ${local.name} storage bucket."
  policy      = data.aws_iam_policy_document.ec2_access[0].json

  tags = merge(var.tags, {
    Name = "${local.name}-ec2-s3-access"
  })
}
