# ==============================================================================
# AWS BEDROCK INTEGRATION MODULE
# Purpose: Provision secure, long-term programmatic credentials for 
#          accessing the MiniMax M2.5 model and store them in Secrets Manager.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. IAM ACCESS POLICY
# What this does: Creates an IAM policy that strictly grants permissions to 
# invoke the specific AWS Bedrock foundation model (MiniMax M2.5). 
# To follow security best practices (Principle of Least Privilege), we limit the
# action to bedrock:InvokeModel and bedrock:InvokeModelWithResponseStream 
# solely on the MiniMax model ARN in the specified region.
# ------------------------------------------------------------------------------
resource "aws_iam_policy" "bedrock_access" {
  name        = "${var.environment}-bedrock-minimax-access"
  description = "Allows invoking the MiniMax M2.5 foundation model on AWS Bedrock"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowInvokeMiniMaxModel"
        Effect   = "Allow"
        Action   = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.model_id}"
        ]
      }
    ]
  })

  tags = var.tags
}

# ------------------------------------------------------------------------------
# 2. DEDICATED IAM USER
# What this does: Creates a standalone IAM User dedicated for external
# developer/local scanning tool integrations. This user will only possess the 
# permissions explicitly attached to it (i.e. the Bedrock Access Policy above).
# ------------------------------------------------------------------------------
resource "aws_iam_user" "bedrock_user" {
  count = var.create_iam_user ? 1 : 0
  name  = "${var.environment}-bedrock-dev-user"
  tags  = var.tags
}

# ------------------------------------------------------------------------------
# 3. POLICY ATTACHMENT
# What this does: Binds the IAM Policy (1) directly to the IAM User (2). 
# This ensures that our newly created user inherits the rights to call Bedrock's 
# MiniMax M2.5 model and nothing else, keeping the credentials extremely secure.
# ------------------------------------------------------------------------------
resource "aws_iam_user_policy_attachment" "bedrock_user_attach" {
  count      = var.create_iam_user ? 1 : 0
  user       = aws_iam_user.bedrock_user[0].name
  policy_arn = aws_iam_policy.bedrock_access.arn
}

# ------------------------------------------------------------------------------
# 4. LONG-TERM ACCESS KEY PAIR
# What this does: Generates a programmatic AWS Access Key ID and Secret Access 
# Key pair for the IAM User. This key pair acts as the long-term, non-expiring
# credential (token) that your developers can use in their local development 
# machines or local scanning tools.
# ------------------------------------------------------------------------------
resource "aws_iam_access_key" "bedrock_key" {
  count = var.create_iam_user ? 1 : 0
  user  = aws_iam_user.bedrock_user[0].name
}

# ------------------------------------------------------------------------------
# 5. AWS SECRETS MANAGER SECRET
# What this does: Creates a secure container within AWS Secrets Manager to store
# the generated Access Key credentials. Storing credentials in Secrets Manager 
# prevents them from being written in plain text in log files, build artifacts, 
# or state files, ensuring enterprise-grade compliance and security.
# ------------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "bedrock_credentials" {
  count                   = var.create_iam_user ? 1 : 0
  name                    = "${var.environment}-bedrock-api-credentials"
  description             = "AWS Access Keys (long-term token) for Bedrock MiniMax Developer Access"
  recovery_window_in_days = 0 # Forces immediate deletion upon terraform destroy

  tags = merge(var.tags, {
    Purpose = "bedrock-developer-authentication"
  })
}

# ------------------------------------------------------------------------------
# 6. SECRETS MANAGER VERSION
# What this does: Injects the actual Access Key ID and Secret Access Key into the
# Secrets Manager container in a JSON object format. This allows developers or 
# local scanners to programmatically query this single secret block to extract
# the required authentication credentials.
# ------------------------------------------------------------------------------
resource "aws_secretsmanager_secret_version" "bedrock_credentials" {
  count     = var.create_iam_user ? 1 : 0
  secret_id = aws_secretsmanager_secret.bedrock_credentials[0].id
  
  secret_string = jsonencode({
    AWS_ACCESS_KEY_ID     = aws_iam_access_key.bedrock_key[0].id
    AWS_SECRET_ACCESS_KEY = aws_iam_access_key.bedrock_key[0].secret
  })
}
