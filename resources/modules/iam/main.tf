# -------------------------------------------------------------------
# IAM Role — EC2 Trust Policy
# -------------------------------------------------------------------
resource "aws_iam_role" "this" {
  name                 = var.role_name
  description          = var.description
  max_session_duration = var.max_session_duration

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge({ Name = var.role_name }, var.tags)
}

# -------------------------------------------------------------------
# Attach AmazonSSMManagedInstanceCore — always attached
# Enables SSM Session Manager, Patch Manager, and Run Command
# -------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# -------------------------------------------------------------------
# Attach additional managed policies (optional — for_each)
# -------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "additional" {
  for_each = toset(var.additional_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

# -------------------------------------------------------------------
# Inline policy (optional — only created when var.inline_policy_json is set)
# -------------------------------------------------------------------
resource "aws_iam_role_policy" "inline" {
  count = var.inline_policy_json != null ? 1 : 0

  name   = "${var.role_name}-inline-policy"
  role   = aws_iam_role.this.name
  policy = var.inline_policy_json
}

# -------------------------------------------------------------------
# Instance Profile — required to attach IAM role to an EC2 instance
# -------------------------------------------------------------------
resource "aws_iam_instance_profile" "this" {
  name = "${var.role_name}-instance-profile"
  role = aws_iam_role.this.name

  tags = merge({ Name = "${var.role_name}-instance-profile" }, var.tags)
}
