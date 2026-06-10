# -------------------------------------------------------------------
# KMS Key
# -------------------------------------------------------------------
resource "aws_kms_key" "this" {
  description             = var.description
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation
  multi_region            = var.multi_region
  policy                  = var.policy

  tags = merge({ Name = var.alias_name }, var.tags)
}

# -------------------------------------------------------------------
# KMS Alias
# -------------------------------------------------------------------
resource "aws_kms_alias" "this" {
  name          = "alias/${var.alias_name}"
  target_key_id = aws_kms_key.this.key_id
}
